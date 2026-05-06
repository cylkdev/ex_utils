defmodule ExUtils.HTTPErrorMessage do
  @moduledoc """
  Translates HTTP status codes into human-readable messages and
  `ErrorMessage` structs.

  Two responsibilities:

    - `status_code_to_message/1` returns a fixed, human-readable string for a
      status code. Recognized codes (300, 301, ..., 511) each have a
      hand-written clause; unrecognized codes fall back to one of three
      bucket messages depending on the 3xx/4xx/5xx range.

    - `status_code_to_error_message/3` turns a status code, a caller-supplied
      `details` payload, and an options list into an `ErrorMessage` struct.
      It selects the named constructor that matches the code (e.g. 401 ->
      `:unauthorized`) and delegates resolution and dispatch of the
      configured error-message module to `ExUtils.Error`. 2xx codes are
      not errors and raise a `RuntimeError`.

  ## Options

  Both functions live in this module, but only `status_code_to_error_message/3`
  consults options:

    * `:status_code_messages` — a keyword list of `{code, message}` overrides.
      When the called code has an entry, that string replaces the default
      message before it is passed to the constructor. Codes without an entry
      use the default from `status_code_to_message/1`.

    * `:error_message_module` — the module that exposes the per-code
      constructors. Defaults to `ErrorMessage`. Resolution and dispatch of
      this module is delegated to `ExUtils.Error`; see its docs for the
      dispatch rules. Useful for tests or for projects that wrap the
      library.

  ## Examples

      iex> ExUtils.HTTPErrorMessage.status_code_to_message(404)
      "the requested resource could not be found"

      iex> ExUtils.HTTPErrorMessage.status_code_to_message(309)
      "redirect not followed"

      iex> %ErrorMessage{code: :unauthorized, message: msg, details: %{tenant: "acme"}} =
      ...>   ExUtils.HTTPErrorMessage.status_code_to_error_message(401, %{tenant: "acme"}, [])
      iex> msg
      "authentication is required to access this resource"

  """

  alias ExUtils.Error

  # Abstraction Function:
  #   The module represents two stateless lookup tables over HTTP status
  #   codes:
  #     `status_code_to_message/1` -> a code -> default human-readable
  #         message map, with three bucket messages handling unrecognized
  #         codes in the 3xx, 4xx, and 5xx ranges.
  #     `status_code_to_error_message/3,4` -> a code -> `ExUtils.Error`
  #         constructor map that builds an `ErrorMessage.t()` whose code
  #         atom mirrors the HTTP status name (e.g. 404 -> :not_found).
  #   Codes outside the explicit table fall through to bucket
  #   constructors: 3xx -> `bad_request`, 4xx -> `not_found`, >= 500 ->
  #   `internal_server_error`.
  #
  # Data Invariant:
  #   1. `status_code_to_message/1` is total over `300..399`,
  #      `400..499`, and `code >= 500`. Codes below 300 raise
  #      `FunctionClauseError`.
  #   2. `status_code_to_error_message/3,4` raises `RuntimeError` for any
  #      `code in 200..299` ("status code <code> is not an error").
  #   3. The 4-arity form supplies the message in this priority order:
  #      explicit `message` argument when binary, else
  #      `opts[:status_code_messages][code]` when present, else
  #      `status_code_to_message(code)`.
  #   4. `:status_code_messages` accepts a `keyword()`, a `map()`, or
  #      `nil` (no overrides).
  #   5. The `details` argument is forwarded verbatim through to
  #      `ExUtils.Error.<name>/3`; this module performs no
  #      validation or transformation on it.
  #
  # Commutative Diagram (status_code_to_error_message/3 dispatch):
  #
  #   (code, details, opts)  --status_code_to_error_message-->  ErrorMessage.t()
  #          |                                                        ^
  #          | message_for(code, nil, opts)                            |
  #          v                                                        |
  #      resolved_message ---ExUtils.Error.<name>(message, details, opts)

  @doc """
  Returns the default human-readable message for an HTTP status code.

  Pure function of its argument: ignores any caller-supplied options.
  Recognized codes return a code-specific message; unrecognized codes
  return one of three bucket messages based on whether the code falls
  in the 3xx, 4xx, or 5xx range.

  ## Parameters

    - `code` - `integer()`. An HTTP status code in the `300..` range.

  ## Returns

  `String.t()`. The hand-written message for the code if it has an
  explicit clause; otherwise one of three bucket strings:

    - `code in 300..399` -> `"redirect not followed"`.
    - `code in 400..499` -> `"client error"`.
    - `code >= 500` -> `"internal server error"`.

  ## Raises

    - `FunctionClauseError` - if `code` is below `300` (no clause matches).

  ## Examples

      iex> ExUtils.HTTPErrorMessage.status_code_to_message(404)
      "the requested resource could not be found"

      iex> ExUtils.HTTPErrorMessage.status_code_to_message(309)
      "redirect not followed"

      iex> ExUtils.HTTPErrorMessage.status_code_to_message(499)
      "client error"

      iex> ExUtils.HTTPErrorMessage.status_code_to_message(599)
      "internal server error"

  """
  @spec status_code_to_message(integer()) :: String.t()
  def status_code_to_message(300), do: "multiple choices available for the requested resource"
  def status_code_to_message(301), do: "the resource has been permanently moved"
  def status_code_to_message(302), do: "the resource was found at a different location"
  def status_code_to_message(303), do: "see other resource for the response"
  def status_code_to_message(304), do: "the resource has not been modified"
  def status_code_to_message(305), do: "the resource must be accessed through a proxy"
  def status_code_to_message(306), do: "the switch proxy status is no longer in use"

  def status_code_to_message(307),
    do: "the request must be repeated against a temporary redirect target"

  def status_code_to_message(308),
    do: "the request must be repeated against the permanent redirect target"

  def status_code_to_message(400),
    do: "the server cannot process the request due to malformed syntax"

  def status_code_to_message(401), do: "authentication is required to access this resource"
  def status_code_to_message(402), do: "payment is required before this resource can be accessed"
  def status_code_to_message(403), do: "the server refuses to authorize this request"
  def status_code_to_message(404), do: "the requested resource could not be found"
  def status_code_to_message(405), do: "the request method is not allowed for this resource"

  def status_code_to_message(406),
    do: "the resource cannot produce a response acceptable to the client"

  def status_code_to_message(407),
    do: "authentication with the proxy is required before the request can proceed"

  def status_code_to_message(408), do: "the server timed out waiting for the request"

  def status_code_to_message(409),
    do: "the request conflicts with the current state of the resource"

  def status_code_to_message(410),
    do: "the resource is no longer available and will not be available again"

  def status_code_to_message(411), do: "the request did not specify the required content length"
  def status_code_to_message(412), do: "a precondition declared in the request headers failed"

  def status_code_to_message(413),
    do: "the request payload is larger than the server is willing to process"

  def status_code_to_message(414),
    do: "the request URI is longer than the server is willing to interpret"

  def status_code_to_message(415),
    do: "the request payload is in a media type the server does not support"

  def status_code_to_message(416), do: "the requested byte range cannot be satisfied"

  def status_code_to_message(417),
    do: "the server cannot meet the expectations declared in the Expect header"

  def status_code_to_message(418), do: "the server refuses to brew coffee because it is a teapot"

  def status_code_to_message(421),
    do: "the request was directed at a server that cannot produce a response"

  def status_code_to_message(422), do: "the request is well-formed but could not be processed"
  def status_code_to_message(423), do: "the resource is locked and cannot be modified"
  def status_code_to_message(424), do: "the request failed because a dependent request failed"

  def status_code_to_message(425),
    do: "the server is unwilling to risk processing a replayed request"

  def status_code_to_message(426), do: "the client must upgrade to a different protocol"

  def status_code_to_message(428),
    do: "the request must be conditional but no precondition was supplied"

  def status_code_to_message(429),
    do: "the client has sent too many requests in the allowed time window"

  def status_code_to_message(431),
    do: "the request headers are too large for the server to process"

  def status_code_to_message(451), do: "the resource is unavailable for legal reasons"
  def status_code_to_message(500), do: "the server encountered an unexpected condition"
  def status_code_to_message(501), do: "the server does not support the functionality required"

  def status_code_to_message(502),
    do: "the server received an invalid response from an upstream server"

  def status_code_to_message(503), do: "the server is temporarily unable to handle the request"
  def status_code_to_message(504), do: "an upstream server failed to respond in time"
  def status_code_to_message(505), do: "the server does not support the requested HTTP version"
  def status_code_to_message(506), do: "content negotiation produced a circular reference"

  def status_code_to_message(507),
    do: "the server has insufficient storage to complete the request"

  def status_code_to_message(508),
    do: "the server detected an infinite loop while processing the request"

  def status_code_to_message(510),
    do: "further extensions to the request are required to fulfill it"

  def status_code_to_message(511), do: "the client must authenticate to gain network access"

  def status_code_to_message(code) when code in 300..399, do: "redirect not followed"
  def status_code_to_message(code) when code in 400..499, do: "client error"
  def status_code_to_message(code) when code >= 500, do: "internal server error"

  @doc """
  Returns an `ErrorMessage.t()` for an HTTP error status code.

  Equivalent to `status_code_to_error_message/4` with `message: nil`.
  The status code chooses the `ExUtils.Error` constructor; the message
  is taken from `opts[:status_code_messages][code]` when present,
  otherwise from `status_code_to_message/1`.

  ## Parameters

    - `code` - `integer()`. An HTTP error status code (`>= 300`).
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying `ExUtils.Error` constructor.
    - `opts` - `keyword()`. Recognised keys:
      `:status_code_messages` (`keyword() | map() | nil`),
      `:error_message_module` (`module()`, forwarded to `ExUtils.Error`).
      Other keys are forwarded but unused by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the chosen
  `ExUtils.Error.<name>/3` call. The `:code` field on the struct is
  the constructor name (e.g. 401 -> `:unauthorized`, 502 ->
  `:bad_gateway`). Unrecognized codes route to a bucket constructor:

    - `300..399` (no explicit clause) -> `bad_request/3`.
    - `400..499` (no explicit clause) -> `not_found/3`.
    - `>= 500` (no explicit clause) -> `internal_server_error/3`.

  ## Raises

    - `RuntimeError` - if `code in 200..299` (`"status code <code> is
      not an error"`).
    - Any exception `ExUtils.Error.<name>/3` raises (e.g. `RuntimeError`
      when the resolved error-message module exports neither
      `<name>/2` nor `call/3`).

  ## Examples

      iex> %ErrorMessage{code: :unauthorized, message: msg, details: %{tenant: "acme"}} =
      ...>   ExUtils.HTTPErrorMessage.status_code_to_error_message(401, %{tenant: "acme"}, [])
      iex> msg
      "authentication is required to access this resource"

  """
  @spec status_code_to_error_message(integer(), term(), keyword()) :: ErrorMessage.t()
  def status_code_to_error_message(code, details, opts) do
    status_code_to_error_message(code, nil, details, opts)
  end

  @doc """
  Returns an `ErrorMessage.t()` for an HTTP error status code with an
  explicit message override.

  Identical to `status_code_to_error_message/3`, except the `message`
  argument is consulted first.

  ## Parameters

    - `code` - `integer()`. An HTTP error status code (`>= 300`).
    - `message` - `String.t() | nil`. When binary, used verbatim as the
      message and takes precedence over `opts[:status_code_messages]`
      and the default. When `nil`, message resolution falls through to
      `opts[:status_code_messages][code]` and then to
      `status_code_to_message/1`.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying `ExUtils.Error` constructor.
    - `opts` - `keyword()`. Recognised keys:
      `:status_code_messages` (`keyword() | map() | nil`),
      `:error_message_module` (`module()`, forwarded to `ExUtils.Error`).

  ## Returns

  `ErrorMessage.t()`. The struct returned by the chosen
  `ExUtils.Error.<name>/3` call. The `:code` field reflects the
  constructor name as listed in `status_code_to_error_message/3`.

  ## Raises

    - `RuntimeError` - if `code in 200..299` (`"status code <code> is
      not an error"`).
    - Any exception `ExUtils.Error.<name>/3` raises.

  ## Examples

      iex> %ErrorMessage{code: :not_found, message: "custom"} =
      ...>   ExUtils.HTTPErrorMessage.status_code_to_error_message(404, "custom", %{}, [])

  """
  @spec status_code_to_error_message(integer(), String.t() | nil, term(), keyword()) ::
          ErrorMessage.t()
  def status_code_to_error_message(code, _message, _details, _opts) when code in 200..299 do
    raise "status code #{code} is not an error"
  end

  def status_code_to_error_message(300 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.multiple_choices(details, opts)
  end

  def status_code_to_error_message(301 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.moved_permanently(details, opts)
  end

  def status_code_to_error_message(302 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.found(details, opts)
  end

  def status_code_to_error_message(303 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.see_other(details, opts)
  end

  def status_code_to_error_message(304 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.not_modified(details, opts)
  end

  def status_code_to_error_message(305 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.use_proxy(details, opts)
  end

  def status_code_to_error_message(306 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.switch_proxy(details, opts)
  end

  def status_code_to_error_message(307 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.temporary_redirect(details, opts)
  end

  def status_code_to_error_message(308 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.permanent_redirect(details, opts)
  end

  def status_code_to_error_message(code, message, details, opts) when code in 300..399 do
    code
    |> message_for(message, opts)
    |> Error.bad_request(details, opts)
  end

  def status_code_to_error_message(400 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.bad_request(details, opts)
  end

  def status_code_to_error_message(401 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.unauthorized(details, opts)
  end

  def status_code_to_error_message(402 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.payment_required(details, opts)
  end

  def status_code_to_error_message(403 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.forbidden(details, opts)
  end

  def status_code_to_error_message(404 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.not_found(details, opts)
  end

  def status_code_to_error_message(405 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.method_not_allowed(details, opts)
  end

  def status_code_to_error_message(406 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.not_acceptable(details, opts)
  end

  def status_code_to_error_message(407 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.proxy_authentication_required(details, opts)
  end

  def status_code_to_error_message(408 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.request_timeout(details, opts)
  end

  def status_code_to_error_message(409 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.conflict(details, opts)
  end

  def status_code_to_error_message(410 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.gone(details, opts)
  end

  def status_code_to_error_message(411 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.length_required(details, opts)
  end

  def status_code_to_error_message(412 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.precondition_failed(details, opts)
  end

  def status_code_to_error_message(413 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.request_entity_too_large(details, opts)
  end

  def status_code_to_error_message(414 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.request_uri_too_long(details, opts)
  end

  def status_code_to_error_message(415 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.unsupported_media_type(details, opts)
  end

  def status_code_to_error_message(416 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.requested_range_not_satisfiable(details, opts)
  end

  def status_code_to_error_message(417 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.expectation_failed(details, opts)
  end

  def status_code_to_error_message(418 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.im_a_teapot(details, opts)
  end

  def status_code_to_error_message(421 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.misdirected_request(details, opts)
  end

  def status_code_to_error_message(422 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.unprocessable_entity(details, opts)
  end

  def status_code_to_error_message(423 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.locked(details, opts)
  end

  def status_code_to_error_message(424 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.failed_dependency(details, opts)
  end

  def status_code_to_error_message(425 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.too_early(details, opts)
  end

  def status_code_to_error_message(426 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.upgrade_required(details, opts)
  end

  def status_code_to_error_message(428 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.precondition_required(details, opts)
  end

  def status_code_to_error_message(429 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.too_many_requests(details, opts)
  end

  def status_code_to_error_message(431 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.request_header_fields_too_large(details, opts)
  end

  def status_code_to_error_message(451 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.unavailable_for_legal_reasons(details, opts)
  end

  def status_code_to_error_message(code, message, details, opts) when code in 400..499 do
    code
    |> message_for(message, opts)
    |> Error.not_found(details, opts)
  end

  def status_code_to_error_message(500 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.internal_server_error(details, opts)
  end

  def status_code_to_error_message(501 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.not_implemented(details, opts)
  end

  def status_code_to_error_message(502 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.bad_gateway(details, opts)
  end

  def status_code_to_error_message(503 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.service_unavailable(details, opts)
  end

  def status_code_to_error_message(504 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.gateway_timeout(details, opts)
  end

  def status_code_to_error_message(505 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.http_version_not_supported(details, opts)
  end

  def status_code_to_error_message(506 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.variant_also_negotiates(details, opts)
  end

  def status_code_to_error_message(507 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.insufficient_storage(details, opts)
  end

  def status_code_to_error_message(508 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.loop_detected(details, opts)
  end

  def status_code_to_error_message(510 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.not_extended(details, opts)
  end

  def status_code_to_error_message(511 = code, message, details, opts) do
    code
    |> message_for(message, opts)
    |> Error.network_authentication_required(details, opts)
  end

  def status_code_to_error_message(code, message, details, opts) when code >= 500 do
    code
    |> message_for(message, opts)
    |> Error.internal_server_error(details, opts)
  end

  defp message_for(_, message, _) when is_binary(message) do
    message
  end

  defp message_for(code, nil, opts) do
    case opts[:status_code_messages] do
      nil -> status_code_to_message(code)
      overrides -> get_msg(overrides, code) || status_code_to_message(code)
    end
  end

  defp get_msg(overrides, code) when is_map(overrides), do: Map.get(overrides, code)

  defp get_msg(overrides, code) when is_list(overrides) do
    case List.keyfind(overrides, code, 0) do
      {^code, message} -> message
      nil -> nil
    end
  end
end
