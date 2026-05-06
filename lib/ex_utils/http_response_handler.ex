defmodule ExUtils.HTTPResponseHandler do
  @moduledoc """
  A two-clause result-tuple bridge for HTTP client calls.

  Encapsulates the common "ok-tuple in, ok-or-error-tuple out" shape
  that wraps an HTTP client response: on success, run a caller
  transform; on `{:http_error, status, response}`, build an
  `ErrorMessage.t()` via `ExUtils.HTTPErrorMessage`.

  ## Responsibilities

    - On `{:ok, response}`, invoke the caller's transform with
      `response` and normalise its return:

        * `{:ok, _}` and `{:error, _}` are passed through unchanged.
        * any other term is wrapped in `{:ok, term}`.

    - On `{:error, {:http_error, status_code, response}}`, return
      `{:error, ErrorMessage.t()}` whose code matches `status_code`.
      The HTTP `response` is placed under the `:response` key inside
      the error's `details`. The message is taken from
      `opts[:http_error][:message]` when supplied; otherwise it falls
      through to `ExUtils.HTTPErrorMessage` defaults.

    - Forward all other `opts` to `ExUtils.HTTPErrorMessage`
      (e.g. `:status_code_messages`, `:error_message_module`).

  ## Examples

      iex> ExUtils.HTTPResponseHandler.handle_response({:ok, :raw}, fn :raw -> {:ok, :ready} end, [])
      {:ok, :ready}

      iex> ExUtils.HTTPResponseHandler.handle_response({:ok, :raw}, fn :raw -> 42 end, [])
      {:ok, 42}

      iex> {:error, %ErrorMessage{code: :not_found, details: %{response: :body}}} =
      ...>   ExUtils.HTTPResponseHandler.handle_response(
      ...>     {:error, {:http_error, 404, :body}},
      ...>     fn _ -> :unused end,
      ...>     []
      ...>   )

  """

  # Abstraction Function:
  #   The module represents a stateless dispatcher that routes a
  #   client-result tuple through one of two paths:
  #     `{:ok, response}` -> apply `fun` and normalise its return.
  #     `{:error, {:http_error, status, response}}` ->
  #         delegate to `ExUtils.HTTPErrorMessage` with `%{response:
  #         response}` as `details`.
  #   The module has no persistent state.
  #
  # Data Invariant:
  #   1. `handle_response/3` matches only the two tuple shapes shown
  #      above; any other shape raises `FunctionClauseError`.
  #   2. On the `{:ok, response}` path, `fun` must be a 1-arity
  #      function (enforced by `is_function(fun, 1)` guard).
  #   3. On the success path the return is normalised: `{:ok, _}` and
  #      `{:error, _}` are passed through; all other terms are wrapped
  #      in `{:ok, term}`.
  #   4. On the error path, the HTTP `response` is forwarded under the
  #      `:response` key in `details`, and `opts[:http_error][:message]`
  #      is forwarded as the explicit message override (defaulting to
  #      `nil` when the key is absent).
  #   5. The full `opts` keyword list is forwarded to
  #      `ExUtils.HTTPErrorMessage.status_code_to_error_message/4`
  #      unchanged.
  #
  # Commutative Diagram (error path):
  #
  #   {:error, {:http_error, code, resp}}, opts
  #             |
  #             | %{response: resp}
  #             v
  #     HTTPErrorMessage.status_code_to_error_message(
  #         code, opts[:http_error][:message], %{response: resp}, opts)
  #             |
  #             v
  #     {:error, ErrorMessage.t()}

  alias ExUtils.HTTPErrorMessage

  @doc """
  Returns a normalised result tuple for an HTTP client response.

  Two cases:

    1. `{:ok, response}` - invoke `fun.(response)` and normalise:
       `{:ok, _}` and `{:error, _}` pass through; any other term is
       wrapped as `{:ok, term}`.
    2. `{:error, {:http_error, status_code, response}}` - return
       `{:error, ErrorMessage.t()}` from `ExUtils.HTTPErrorMessage`,
       with `%{response: response}` placed in `details`.

  ## Parameters

    - `result` - one of `{:ok, term()}` or
      `{:error, {:http_error, integer(), term()}}`. No other tuple
      shape is accepted.
    - `fun` - 1-arity function. Invoked only on the `{:ok, _}` branch.
      Required to be a 1-arity function on the success branch
      (enforced by `is_function(fun, 1)` guard); ignored on the error
      branch.
    - `opts` - `keyword()`. Recognised keys:

        * `:http_error` - keyword list. `:http_error[:message]` is
          forwarded to `ExUtils.HTTPErrorMessage` as the explicit
          message override; defaults to `nil` when absent.
        * any key consumed by `ExUtils.HTTPErrorMessage` (e.g.
          `:status_code_messages`, `:error_message_module`) is
          forwarded unchanged.

  ## Returns

  `{:ok, term()} | {:error, ErrorMessage.t()} | {:error, term()}`.

  On the success branch, the shape is `{:ok, _}`, `{:error, _}`, or
  `{:ok, fun.(response)}` depending on what `fun` returned. On the
  error branch, the shape is always `{:error, ErrorMessage.t()}` with
  `:code` derived from `status_code` (see `ExUtils.HTTPErrorMessage`).
  No global state is touched.

  ## Raises

    - `FunctionClauseError` - if `result` is neither
      `{:ok, _}` nor `{:error, {:http_error, _, _}}`, or if `fun` on
      the success branch is not a 1-arity function.
    - `RuntimeError` - if `status_code in 200..299` (propagated from
      `ExUtils.HTTPErrorMessage`).
    - Any exception raised by `fun` on the success branch is propagated.

  ## Examples

      iex> ExUtils.HTTPResponseHandler.handle_response({:ok, :raw}, fn :raw -> {:ok, :ready} end, [])
      {:ok, :ready}

      iex> ExUtils.HTTPResponseHandler.handle_response({:ok, :raw}, fn :raw -> {:error, :reason} end, [])
      {:error, :reason}

      iex> ExUtils.HTTPResponseHandler.handle_response({:ok, :raw}, fn :raw -> 42 end, [])
      {:ok, 42}

      iex> {:error, %ErrorMessage{code: :unauthorized, message: "custom msg"}} =
      ...>   ExUtils.HTTPResponseHandler.handle_response(
      ...>     {:error, {:http_error, 401, :body}},
      ...>     fn _ -> :unused end,
      ...>     http_error: [message: "custom msg"]
      ...>   )

  """
  @spec handle_response(
          {:ok, term()} | {:error, {:http_error, integer(), term()}},
          (term() -> term()),
          keyword()
        ) :: {:ok, term()} | {:error, ErrorMessage.t() | term()}
  def handle_response({:ok, response}, fun, _opts) when is_function(fun, 1) do
    case fun.(response) do
      {:ok, _} = ok -> ok
      {:error, _} = error -> error
      term -> {:ok, term}
    end
  end

  def handle_response({:error, {:http_error, status_code, response}}, _fun, opts) do
    {
      :error,
      HTTPErrorMessage.status_code_to_error_message(
        status_code,
        opts[:http_error][:message],
        %{response: response},
        opts
      )
    }
  end
end
