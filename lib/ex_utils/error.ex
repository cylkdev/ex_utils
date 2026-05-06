defmodule ExUtils.Error do
  @moduledoc """
  Builders for HTTP-shaped `ErrorMessage` structs.

  Exposes one named constructor per HTTP error code (e.g. `not_found/3`,
  `unauthorized/3`, `internal_server_error/3`). Every public function in
  the module has the same shape `(message, details, opts) ->
  ErrorMessage.t()` and forwards to a configurable underlying
  error-message module via one of two interfaces.

  ## Responsibilities

    - Provide a per-error-code constructor for every HTTP error name in
      the supported set (3xx redirect, 4xx client, 5xx server).
    - Resolve the underlying module from `opts[:error_message_module]`,
      falling back to `ErrorMessage`.
    - Dispatch to the resolved module using the first interface it
      exports, in this order:

        1. `mod.<name>/2` - the per-name constructor.
        2. `mod.call/3` - a single generic dispatcher receiving the name
           atom as its first argument.

    - Raise `RuntimeError` when neither interface is exported, naming
      the offending module.

  ## Options

    * `:error_message_module` - the module that exposes the per-name
      constructors. Defaults to `ErrorMessage`. Useful for tests or for
      projects that wrap the library and supply their own
      error-message module.

  ## Examples

      iex> %ErrorMessage{code: :not_found, message: msg, details: %{id: 1}} =
      ...>   ExUtils.Error.not_found("missing", %{id: 1}, [])
      iex> msg
      "missing"

  """

  # Abstraction Function:
  #   The module represents a stateless dispatch table from named HTTP
  #   error atoms to an underlying error-message module. Each public
  #   function `name/3` represents the partial map
  #     (message, details, opts) -> ErrorMessage.t()
  #   that resolves the underlying module from `opts` and applies the
  #   matching constructor.
  #   `@default_error_message_module` represents the implicit underlying
  #   module used when `opts[:error_message_module]` is absent.
  #
  # Data Invariant:
  #   1. `error_message_module(opts)` returns a non-`nil` module:
  #      `opts[:error_message_module]` if present, otherwise
  #      `@default_error_message_module`.
  #   2. Each public function probes its named constructor first
  #      (`function_exported?(mod, name, 2)`); the generic `call/3`
  #      dispatcher is consulted only when the named constructor is not
  #      exported.
  #   3. When neither interface is exported, the function raises
  #      `RuntimeError` whose message names the offending module.
  #   4. Inputs are forwarded unchanged: `message` and `details` are
  #      passed to the underlying module without modification.
  #   5. The module has no persistent state and performs no logging or
  #      side effects beyond the underlying call.
  #
  # Commutative Diagram (dispatch for any name `N`):
  #
  #   (message, details, opts)  --ExUtils.Error.N-->  ErrorMessage.t()
  #          |                                              ^
  #          | error_message_module(opts)                   |
  #          v                                              |
  #     resolved_mod -- mod.N(message, details) OR ---------+
  #                     mod.call(:N, message, details)

  @default_error_message_module ErrorMessage

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:multiple_choices`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `multiple_choices/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:multiple_choices` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `multiple_choices/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :multiple_choices} =
      ...>   ExUtils.Error.multiple_choices("oops", %{}, [])

  """
  @spec multiple_choices(String.t(), term(), keyword()) :: ErrorMessage.t()
  def multiple_choices(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :multiple_choices, 2) ->
        mod.multiple_choices(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:multiple_choices, message, details)

      true ->
        raise "Error message module must implement :multiple_choices/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:moved_permanently`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `moved_permanently/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:moved_permanently` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `moved_permanently/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :moved_permanently} =
      ...>   ExUtils.Error.moved_permanently("oops", %{}, [])

  """
  @spec moved_permanently(String.t(), term(), keyword()) :: ErrorMessage.t()
  def moved_permanently(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :moved_permanently, 2) ->
        mod.moved_permanently(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:moved_permanently, message, details)

      true ->
        raise "Error message module must implement :moved_permanently/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:found`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `found/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:found` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `found/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :found} =
      ...>   ExUtils.Error.found("oops", %{}, [])

  """
  @spec found(String.t(), term(), keyword()) :: ErrorMessage.t()
  def found(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :found, 2) ->
        mod.found(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:found, message, details)

      true ->
        raise "Error message module must implement :found/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:see_other`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `see_other/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:see_other` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `see_other/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :see_other} =
      ...>   ExUtils.Error.see_other("oops", %{}, [])

  """
  @spec see_other(String.t(), term(), keyword()) :: ErrorMessage.t()
  def see_other(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :see_other, 2) ->
        mod.see_other(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:see_other, message, details)

      true ->
        raise "Error message module must implement :see_other/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:not_modified`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `not_modified/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:not_modified` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `not_modified/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :not_modified} =
      ...>   ExUtils.Error.not_modified("oops", %{}, [])

  """
  @spec not_modified(String.t(), term(), keyword()) :: ErrorMessage.t()
  def not_modified(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :not_modified, 2) ->
        mod.not_modified(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:not_modified, message, details)

      true ->
        raise "Error message module must implement :not_modified/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:use_proxy`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `use_proxy/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:use_proxy` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `use_proxy/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :use_proxy} =
      ...>   ExUtils.Error.use_proxy("oops", %{}, [])

  """
  @spec use_proxy(String.t(), term(), keyword()) :: ErrorMessage.t()
  def use_proxy(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :use_proxy, 2) ->
        mod.use_proxy(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:use_proxy, message, details)

      true ->
        raise "Error message module must implement :use_proxy/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:switch_proxy`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `switch_proxy/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:switch_proxy` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `switch_proxy/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :switch_proxy} =
      ...>   ExUtils.Error.switch_proxy("oops", %{}, [])

  """
  @spec switch_proxy(String.t(), term(), keyword()) :: ErrorMessage.t()
  def switch_proxy(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :switch_proxy, 2) ->
        mod.switch_proxy(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:switch_proxy, message, details)

      true ->
        raise "Error message module must implement :switch_proxy/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:temporary_redirect`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `temporary_redirect/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:temporary_redirect` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `temporary_redirect/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :temporary_redirect} =
      ...>   ExUtils.Error.temporary_redirect("oops", %{}, [])

  """
  @spec temporary_redirect(String.t(), term(), keyword()) :: ErrorMessage.t()
  def temporary_redirect(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :temporary_redirect, 2) ->
        mod.temporary_redirect(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:temporary_redirect, message, details)

      true ->
        raise "Error message module must implement :temporary_redirect/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:permanent_redirect`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `permanent_redirect/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:permanent_redirect` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `permanent_redirect/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :permanent_redirect} =
      ...>   ExUtils.Error.permanent_redirect("oops", %{}, [])

  """
  @spec permanent_redirect(String.t(), term(), keyword()) :: ErrorMessage.t()
  def permanent_redirect(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :permanent_redirect, 2) ->
        mod.permanent_redirect(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:permanent_redirect, message, details)

      true ->
        raise "Error message module must implement :permanent_redirect/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:bad_request`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `bad_request/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:bad_request` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `bad_request/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :bad_request} =
      ...>   ExUtils.Error.bad_request("oops", %{}, [])

  """
  @spec bad_request(String.t(), term(), keyword()) :: ErrorMessage.t()
  def bad_request(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :bad_request, 2) ->
        mod.bad_request(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:bad_request, message, details)

      true ->
        raise "Error message module must implement :bad_request/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:unauthorized`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `unauthorized/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:unauthorized` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `unauthorized/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :unauthorized} =
      ...>   ExUtils.Error.unauthorized("oops", %{}, [])

  """
  @spec unauthorized(String.t(), term(), keyword()) :: ErrorMessage.t()
  def unauthorized(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :unauthorized, 2) ->
        mod.unauthorized(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:unauthorized, message, details)

      true ->
        raise "Error message module must implement :unauthorized/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:payment_required`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `payment_required/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:payment_required` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `payment_required/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :payment_required} =
      ...>   ExUtils.Error.payment_required("oops", %{}, [])

  """
  @spec payment_required(String.t(), term(), keyword()) :: ErrorMessage.t()
  def payment_required(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :payment_required, 2) ->
        mod.payment_required(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:payment_required, message, details)

      true ->
        raise "Error message module must implement :payment_required/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:forbidden`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `forbidden/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:forbidden` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `forbidden/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :forbidden} =
      ...>   ExUtils.Error.forbidden("oops", %{}, [])

  """
  @spec forbidden(String.t(), term(), keyword()) :: ErrorMessage.t()
  def forbidden(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :forbidden, 2) ->
        mod.forbidden(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:forbidden, message, details)

      true ->
        raise "Error message module must implement :forbidden/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:not_found`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `not_found/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:not_found` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `not_found/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :not_found} =
      ...>   ExUtils.Error.not_found("oops", %{}, [])

  """
  @spec not_found(String.t(), term(), keyword()) :: ErrorMessage.t()
  def not_found(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :not_found, 2) ->
        mod.not_found(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:not_found, message, details)

      true ->
        raise "Error message module must implement :not_found/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:method_not_allowed`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `method_not_allowed/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:method_not_allowed` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `method_not_allowed/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :method_not_allowed} =
      ...>   ExUtils.Error.method_not_allowed("oops", %{}, [])

  """
  @spec method_not_allowed(String.t(), term(), keyword()) :: ErrorMessage.t()
  def method_not_allowed(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :method_not_allowed, 2) ->
        mod.method_not_allowed(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:method_not_allowed, message, details)

      true ->
        raise "Error message module must implement :method_not_allowed/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:not_acceptable`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `not_acceptable/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:not_acceptable` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `not_acceptable/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :not_acceptable} =
      ...>   ExUtils.Error.not_acceptable("oops", %{}, [])

  """
  @spec not_acceptable(String.t(), term(), keyword()) :: ErrorMessage.t()
  def not_acceptable(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :not_acceptable, 2) ->
        mod.not_acceptable(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:not_acceptable, message, details)

      true ->
        raise "Error message module must implement :not_acceptable/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:proxy_authentication_required`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `proxy_authentication_required/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:proxy_authentication_required` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `proxy_authentication_required/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :proxy_authentication_required} =
      ...>   ExUtils.Error.proxy_authentication_required("oops", %{}, [])

  """
  @spec proxy_authentication_required(String.t(), term(), keyword()) :: ErrorMessage.t()
  def proxy_authentication_required(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :proxy_authentication_required, 2) ->
        mod.proxy_authentication_required(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:proxy_authentication_required, message, details)

      true ->
        raise "Error message module must implement :proxy_authentication_required/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:request_timeout`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `request_timeout/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:request_timeout` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `request_timeout/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :request_timeout} =
      ...>   ExUtils.Error.request_timeout("oops", %{}, [])

  """
  @spec request_timeout(String.t(), term(), keyword()) :: ErrorMessage.t()
  def request_timeout(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :request_timeout, 2) ->
        mod.request_timeout(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:request_timeout, message, details)

      true ->
        raise "Error message module must implement :request_timeout/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:conflict`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `conflict/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:conflict` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `conflict/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :conflict} =
      ...>   ExUtils.Error.conflict("oops", %{}, [])

  """
  @spec conflict(String.t(), term(), keyword()) :: ErrorMessage.t()
  def conflict(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :conflict, 2) ->
        mod.conflict(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:conflict, message, details)

      true ->
        raise "Error message module must implement :conflict/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:gone`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `gone/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:gone` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `gone/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :gone} =
      ...>   ExUtils.Error.gone("oops", %{}, [])

  """
  @spec gone(String.t(), term(), keyword()) :: ErrorMessage.t()
  def gone(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :gone, 2) ->
        mod.gone(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:gone, message, details)

      true ->
        raise "Error message module must implement :gone/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:length_required`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `length_required/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:length_required` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `length_required/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :length_required} =
      ...>   ExUtils.Error.length_required("oops", %{}, [])

  """
  @spec length_required(String.t(), term(), keyword()) :: ErrorMessage.t()
  def length_required(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :length_required, 2) ->
        mod.length_required(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:length_required, message, details)

      true ->
        raise "Error message module must implement :length_required/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:precondition_failed`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `precondition_failed/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:precondition_failed` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `precondition_failed/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :precondition_failed} =
      ...>   ExUtils.Error.precondition_failed("oops", %{}, [])

  """
  @spec precondition_failed(String.t(), term(), keyword()) :: ErrorMessage.t()
  def precondition_failed(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :precondition_failed, 2) ->
        mod.precondition_failed(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:precondition_failed, message, details)

      true ->
        raise "Error message module must implement :precondition_failed/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:request_entity_too_large`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `request_entity_too_large/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:request_entity_too_large` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `request_entity_too_large/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :request_entity_too_large} =
      ...>   ExUtils.Error.request_entity_too_large("oops", %{}, [])

  """
  @spec request_entity_too_large(String.t(), term(), keyword()) :: ErrorMessage.t()
  def request_entity_too_large(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :request_entity_too_large, 2) ->
        mod.request_entity_too_large(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:request_entity_too_large, message, details)

      true ->
        raise "Error message module must implement :request_entity_too_large/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:request_uri_too_long`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `request_uri_too_long/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:request_uri_too_long` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `request_uri_too_long/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :request_uri_too_long} =
      ...>   ExUtils.Error.request_uri_too_long("oops", %{}, [])

  """
  @spec request_uri_too_long(String.t(), term(), keyword()) :: ErrorMessage.t()
  def request_uri_too_long(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :request_uri_too_long, 2) ->
        mod.request_uri_too_long(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:request_uri_too_long, message, details)

      true ->
        raise "Error message module must implement :request_uri_too_long/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:unsupported_media_type`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `unsupported_media_type/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:unsupported_media_type` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `unsupported_media_type/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :unsupported_media_type} =
      ...>   ExUtils.Error.unsupported_media_type("oops", %{}, [])

  """
  @spec unsupported_media_type(String.t(), term(), keyword()) :: ErrorMessage.t()
  def unsupported_media_type(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :unsupported_media_type, 2) ->
        mod.unsupported_media_type(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:unsupported_media_type, message, details)

      true ->
        raise "Error message module must implement :unsupported_media_type/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:requested_range_not_satisfiable`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `requested_range_not_satisfiable/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:requested_range_not_satisfiable` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `requested_range_not_satisfiable/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :requested_range_not_satisfiable} =
      ...>   ExUtils.Error.requested_range_not_satisfiable("oops", %{}, [])

  """
  @spec requested_range_not_satisfiable(String.t(), term(), keyword()) :: ErrorMessage.t()
  def requested_range_not_satisfiable(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :requested_range_not_satisfiable, 2) ->
        mod.requested_range_not_satisfiable(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:requested_range_not_satisfiable, message, details)

      true ->
        raise "Error message module must implement :requested_range_not_satisfiable/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:expectation_failed`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `expectation_failed/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:expectation_failed` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `expectation_failed/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :expectation_failed} =
      ...>   ExUtils.Error.expectation_failed("oops", %{}, [])

  """
  @spec expectation_failed(String.t(), term(), keyword()) :: ErrorMessage.t()
  def expectation_failed(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :expectation_failed, 2) ->
        mod.expectation_failed(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:expectation_failed, message, details)

      true ->
        raise "Error message module must implement :expectation_failed/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:im_a_teapot`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `im_a_teapot/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:im_a_teapot` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `im_a_teapot/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :im_a_teapot} =
      ...>   ExUtils.Error.im_a_teapot("oops", %{}, [])

  """
  @spec im_a_teapot(String.t(), term(), keyword()) :: ErrorMessage.t()
  def im_a_teapot(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :im_a_teapot, 2) ->
        mod.im_a_teapot(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:im_a_teapot, message, details)

      true ->
        raise "Error message module must implement :im_a_teapot/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:misdirected_request`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `misdirected_request/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:misdirected_request` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `misdirected_request/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :misdirected_request} =
      ...>   ExUtils.Error.misdirected_request("oops", %{}, [])

  """
  @spec misdirected_request(String.t(), term(), keyword()) :: ErrorMessage.t()
  def misdirected_request(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :misdirected_request, 2) ->
        mod.misdirected_request(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:misdirected_request, message, details)

      true ->
        raise "Error message module must implement :misdirected_request/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:unprocessable_entity`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `unprocessable_entity/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:unprocessable_entity` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `unprocessable_entity/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :unprocessable_entity} =
      ...>   ExUtils.Error.unprocessable_entity("oops", %{}, [])

  """
  @spec unprocessable_entity(String.t(), term(), keyword()) :: ErrorMessage.t()
  def unprocessable_entity(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :unprocessable_entity, 2) ->
        mod.unprocessable_entity(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:unprocessable_entity, message, details)

      true ->
        raise "Error message module must implement :unprocessable_entity/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:locked`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `locked/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:locked` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `locked/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :locked} =
      ...>   ExUtils.Error.locked("oops", %{}, [])

  """
  @spec locked(String.t(), term(), keyword()) :: ErrorMessage.t()
  def locked(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :locked, 2) ->
        mod.locked(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:locked, message, details)

      true ->
        raise "Error message module must implement :locked/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:failed_dependency`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `failed_dependency/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:failed_dependency` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `failed_dependency/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :failed_dependency} =
      ...>   ExUtils.Error.failed_dependency("oops", %{}, [])

  """
  @spec failed_dependency(String.t(), term(), keyword()) :: ErrorMessage.t()
  def failed_dependency(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :failed_dependency, 2) ->
        mod.failed_dependency(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:failed_dependency, message, details)

      true ->
        raise "Error message module must implement :failed_dependency/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:too_early`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `too_early/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:too_early` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `too_early/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :too_early} =
      ...>   ExUtils.Error.too_early("oops", %{}, [])

  """
  @spec too_early(String.t(), term(), keyword()) :: ErrorMessage.t()
  def too_early(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :too_early, 2) ->
        mod.too_early(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:too_early, message, details)

      true ->
        raise "Error message module must implement :too_early/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:upgrade_required`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `upgrade_required/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:upgrade_required` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `upgrade_required/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :upgrade_required} =
      ...>   ExUtils.Error.upgrade_required("oops", %{}, [])

  """
  @spec upgrade_required(String.t(), term(), keyword()) :: ErrorMessage.t()
  def upgrade_required(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :upgrade_required, 2) ->
        mod.upgrade_required(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:upgrade_required, message, details)

      true ->
        raise "Error message module must implement :upgrade_required/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:precondition_required`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `precondition_required/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:precondition_required` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `precondition_required/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :precondition_required} =
      ...>   ExUtils.Error.precondition_required("oops", %{}, [])

  """
  @spec precondition_required(String.t(), term(), keyword()) :: ErrorMessage.t()
  def precondition_required(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :precondition_required, 2) ->
        mod.precondition_required(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:precondition_required, message, details)

      true ->
        raise "Error message module must implement :precondition_required/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:too_many_requests`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `too_many_requests/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:too_many_requests` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `too_many_requests/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :too_many_requests} =
      ...>   ExUtils.Error.too_many_requests("oops", %{}, [])

  """
  @spec too_many_requests(String.t(), term(), keyword()) :: ErrorMessage.t()
  def too_many_requests(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :too_many_requests, 2) ->
        mod.too_many_requests(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:too_many_requests, message, details)

      true ->
        raise "Error message module must implement :too_many_requests/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:request_header_fields_too_large`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `request_header_fields_too_large/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:request_header_fields_too_large` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `request_header_fields_too_large/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :request_header_fields_too_large} =
      ...>   ExUtils.Error.request_header_fields_too_large("oops", %{}, [])

  """
  @spec request_header_fields_too_large(String.t(), term(), keyword()) :: ErrorMessage.t()
  def request_header_fields_too_large(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :request_header_fields_too_large, 2) ->
        mod.request_header_fields_too_large(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:request_header_fields_too_large, message, details)

      true ->
        raise "Error message module must implement :request_header_fields_too_large/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:unavailable_for_legal_reasons`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `unavailable_for_legal_reasons/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:unavailable_for_legal_reasons` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `unavailable_for_legal_reasons/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :unavailable_for_legal_reasons} =
      ...>   ExUtils.Error.unavailable_for_legal_reasons("oops", %{}, [])

  """
  @spec unavailable_for_legal_reasons(String.t(), term(), keyword()) :: ErrorMessage.t()
  def unavailable_for_legal_reasons(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :unavailable_for_legal_reasons, 2) ->
        mod.unavailable_for_legal_reasons(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:unavailable_for_legal_reasons, message, details)

      true ->
        raise "Error message module must implement :unavailable_for_legal_reasons/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:internal_server_error`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `internal_server_error/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:internal_server_error` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `internal_server_error/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :internal_server_error} =
      ...>   ExUtils.Error.internal_server_error("oops", %{}, [])

  """
  @spec internal_server_error(String.t(), term(), keyword()) :: ErrorMessage.t()
  def internal_server_error(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :internal_server_error, 2) ->
        mod.internal_server_error(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:internal_server_error, message, details)

      true ->
        raise "Error message module must implement :internal_server_error/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:not_implemented`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `not_implemented/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:not_implemented` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `not_implemented/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :not_implemented} =
      ...>   ExUtils.Error.not_implemented("oops", %{}, [])

  """
  @spec not_implemented(String.t(), term(), keyword()) :: ErrorMessage.t()
  def not_implemented(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :not_implemented, 2) ->
        mod.not_implemented(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:not_implemented, message, details)

      true ->
        raise "Error message module must implement :not_implemented/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:bad_gateway`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `bad_gateway/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:bad_gateway` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `bad_gateway/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :bad_gateway} =
      ...>   ExUtils.Error.bad_gateway("oops", %{}, [])

  """
  @spec bad_gateway(String.t(), term(), keyword()) :: ErrorMessage.t()
  def bad_gateway(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :bad_gateway, 2) ->
        mod.bad_gateway(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:bad_gateway, message, details)

      true ->
        raise "Error message module must implement :bad_gateway/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:service_unavailable`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `service_unavailable/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:service_unavailable` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `service_unavailable/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :service_unavailable} =
      ...>   ExUtils.Error.service_unavailable("oops", %{}, [])

  """
  @spec service_unavailable(String.t(), term(), keyword()) :: ErrorMessage.t()
  def service_unavailable(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :service_unavailable, 2) ->
        mod.service_unavailable(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:service_unavailable, message, details)

      true ->
        raise "Error message module must implement :service_unavailable/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:gateway_timeout`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `gateway_timeout/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:gateway_timeout` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `gateway_timeout/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :gateway_timeout} =
      ...>   ExUtils.Error.gateway_timeout("oops", %{}, [])

  """
  @spec gateway_timeout(String.t(), term(), keyword()) :: ErrorMessage.t()
  def gateway_timeout(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :gateway_timeout, 2) ->
        mod.gateway_timeout(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:gateway_timeout, message, details)

      true ->
        raise "Error message module must implement :gateway_timeout/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:http_version_not_supported`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `http_version_not_supported/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:http_version_not_supported` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `http_version_not_supported/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :http_version_not_supported} =
      ...>   ExUtils.Error.http_version_not_supported("oops", %{}, [])

  """
  @spec http_version_not_supported(String.t(), term(), keyword()) :: ErrorMessage.t()
  def http_version_not_supported(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :http_version_not_supported, 2) ->
        mod.http_version_not_supported(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:http_version_not_supported, message, details)

      true ->
        raise "Error message module must implement :http_version_not_supported/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:variant_also_negotiates`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `variant_also_negotiates/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:variant_also_negotiates` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `variant_also_negotiates/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :variant_also_negotiates} =
      ...>   ExUtils.Error.variant_also_negotiates("oops", %{}, [])

  """
  @spec variant_also_negotiates(String.t(), term(), keyword()) :: ErrorMessage.t()
  def variant_also_negotiates(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :variant_also_negotiates, 2) ->
        mod.variant_also_negotiates(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:variant_also_negotiates, message, details)

      true ->
        raise "Error message module must implement :variant_also_negotiates/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:insufficient_storage`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `insufficient_storage/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:insufficient_storage` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `insufficient_storage/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :insufficient_storage} =
      ...>   ExUtils.Error.insufficient_storage("oops", %{}, [])

  """
  @spec insufficient_storage(String.t(), term(), keyword()) :: ErrorMessage.t()
  def insufficient_storage(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :insufficient_storage, 2) ->
        mod.insufficient_storage(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:insufficient_storage, message, details)

      true ->
        raise "Error message module must implement :insufficient_storage/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:loop_detected`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `loop_detected/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:loop_detected` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `loop_detected/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :loop_detected} =
      ...>   ExUtils.Error.loop_detected("oops", %{}, [])

  """
  @spec loop_detected(String.t(), term(), keyword()) :: ErrorMessage.t()
  def loop_detected(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :loop_detected, 2) ->
        mod.loop_detected(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:loop_detected, message, details)

      true ->
        raise "Error message module must implement :loop_detected/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:not_extended`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `not_extended/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:not_extended` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `not_extended/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :not_extended} =
      ...>   ExUtils.Error.not_extended("oops", %{}, [])

  """
  @spec not_extended(String.t(), term(), keyword()) :: ErrorMessage.t()
  def not_extended(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :not_extended, 2) ->
        mod.not_extended(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:not_extended, message, details)

      true ->
        raise "Error message module must implement :not_extended/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  @doc """
  Returns an `ErrorMessage.t()` whose code is `:network_authentication_required`, built by the
  resolved error-message module.

  ## Parameters

    - `message` - `String.t()`. Human-readable description forwarded
      verbatim to the underlying constructor.
    - `details` - `term()`. Caller-supplied payload forwarded verbatim
      to the underlying constructor.
    - `opts` - `keyword()`. Recognised key:
      `:error_message_module` (`module()`, default `ErrorMessage`).
      Other keys are ignored by this function.

  ## Returns

  `ErrorMessage.t()`. The struct returned by the underlying module.
  When the resolved module exports `network_authentication_required/2`, that function is
  invoked. Otherwise, when the module exports `call/3`, it is invoked
  with `:network_authentication_required` as its first argument. The function does not modify
  the returned struct.

  ## Raises

    - `RuntimeError` - if the resolved module exports neither
      `network_authentication_required/2` nor `call/3`. The message names the offending module.
    - Any exception the underlying constructor raises is propagated
      unchanged.

  ## Examples

      iex> %ErrorMessage{code: :network_authentication_required} =
      ...>   ExUtils.Error.network_authentication_required("oops", %{}, [])

  """
  @spec network_authentication_required(String.t(), term(), keyword()) :: ErrorMessage.t()
  def network_authentication_required(message, details, opts) do
    mod = error_message_module(opts)

    cond do
      function_exported?(mod, :network_authentication_required, 2) ->
        mod.network_authentication_required(message, details)

      function_exported?(mod, :call, 3) ->
        mod.call(:network_authentication_required, message, details)

      true ->
        raise "Error message module must implement :network_authentication_required/2 or :call/3, got: #{inspect(mod)}"
    end
  end

  defp error_message_module(opts) do
    opts[:error_message_module] || @default_error_message_module
  end
end
