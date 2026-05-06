defmodule ExUtils.Logger do
  @moduledoc """
  A small prefix-and-format wrapper around Elixir's `Logger`.

  Each level (`debug/4`, `info/4`, `warning/4`, `error/4`) takes a
  `prefix`, a `message`, optional logger `metadata`, and optional
  formatting `opts`. The prefix and message are formatted into a
  single string and forwarded to the matching `Logger` macro.

  The default formatter produces `"[<prefix>] <message>"`. A caller
  may override formatting per call with
  `format_message: fn prefix, message -> ... end`.

  ## Responsibilities

    - Emit log entries at four levels: debug, info, warning, error.
    - Format the prefix and message with the default formatter
      (`"[\#{prefix}] \#{message}"`) or with a caller-supplied 2-arity
      function provided via `:format_message`.
    - Forward `metadata` (default `[]`) to the underlying `Logger`
      call.
    - Compatibility shim for OTP/Elixir versions that lack
      `Logger.warning/2`: when `Logger` does not export `warning/2`,
      `warning/4` falls through to `Logger.warn/2`.

  ## Examples

      ExUtils.Logger.info("App", "starting up")
      #=> emits "[App] starting up" at :info level

      ExUtils.Logger.debug(
        "App",
        "ping",
        [request_id: "abc"],
        format_message: fn p, m -> "<\#{p}>::<\#{m}>" end
      )
      #=> emits "<App>::<ping>" at :debug level with metadata [request_id: "abc"]

  """

  # Abstraction Function:
  #   The module represents four side-effecting entry points (one per
  #   `Logger` level) that share the same shape and pipeline:
  #     prefix |> format_message(message, opts) |> Logger.<level>(metadata).
  #   `format_message/3` represents the dispatch over `opts[:format_message]`:
  #     - 2-arity function -> caller-supplied formatter,
  #     - 1-or-other-arity function -> raise `ArgumentError`,
  #     - anything else (including absent) -> default `"[prefix] message"`.
  #   The module has no persistent state; observable side effects come
  #   from `Logger`.
  #
  # Data Invariant:
  #   1. Every level function delegates to its matching `Logger` macro
  #      and returns whatever that macro returns (typically `:ok`).
  #   2. The `metadata` argument is forwarded verbatim to `Logger` as
  #      the second argument; default value is `[]`.
  #   3. `opts[:format_message]`, when supplied, must be a function. A
  #      function whose arity is not 2 raises `ArgumentError`.
  #   4. When `opts[:format_message]` is not a function (including the
  #      absent case), the default formatter `"[#{prefix}] #{message}"`
  #      is used.
  #   5. `warning/4` is conditionally compiled: if `Logger.warning/2`
  #      is exported, it is used; otherwise `Logger.warn/2` is used.
  #
  # Commutative Diagram (any level `L`):
  #
  #   (prefix, message, metadata, opts)
  #              |
  #              | format_message(prefix, message, opts)
  #              v
  #         formatted ----- Logger.L(formatted, metadata) -----> :ok

  require Logger

  @doc """
  Logs `message` at `:debug` level with the formatted prefix.

  Pipeline: `prefix |> format_message(message, opts) |> Logger.debug(metadata)`.

  ## Parameters

    - `prefix` - `binary()`. Forwarded to the formatter.
    - `message` - `binary()`. Forwarded to the formatter.
    - `metadata` - `keyword()`. Default `[]`. Forwarded verbatim to
      `Logger.debug/2`.
    - `opts` - `keyword()`. Default `[]`. Recognised key:
      `:format_message` (2-arity function). Other keys are ignored.

  ## Returns

  `:ok`. Whatever `Logger.debug/2` returns. The visible effect is a
  log entry at `:debug` level when the configured `Logger` level
  permits.

  ## Raises

    - `ArgumentError` - if `opts[:format_message]` is a function whose
      arity is not 2.

  ## Examples

      ExUtils.Logger.debug("App", "tick")
      # => emits "[App] tick" at :debug

  """
  @spec debug(prefix :: binary(), message :: binary(), metadata :: keyword(), opts :: keyword()) ::
          :ok
  def debug(prefix, message, metadata \\ [], opts \\ []) do
    prefix
    |> format_message(message, opts)
    |> Logger.debug(metadata)
  end

  @doc """
  Logs `message` at `:info` level with the formatted prefix.

  Pipeline: `prefix |> format_message(message, opts) |> Logger.info(metadata)`.

  ## Parameters

    - `prefix` - `binary()`. Forwarded to the formatter.
    - `message` - `binary()`. Forwarded to the formatter.
    - `metadata` - `keyword()`. Default `[]`. Forwarded verbatim to
      `Logger.info/2`.
    - `opts` - `keyword()`. Default `[]`. Recognised key:
      `:format_message` (2-arity function). Other keys are ignored.

  ## Returns

  `:ok`. Whatever `Logger.info/2` returns. The visible effect is a
  log entry at `:info` level when the configured `Logger` level
  permits.

  ## Raises

    - `ArgumentError` - if `opts[:format_message]` is a function whose
      arity is not 2.

  ## Examples

      ExUtils.Logger.info("App", "started")
      # => emits "[App] started" at :info

  """
  @spec info(prefix :: binary(), message :: binary(), metadata :: keyword(), opts :: keyword()) ::
          :ok
  def info(prefix, message, metadata \\ [], opts \\ []) do
    prefix
    |> format_message(message, opts)
    |> Logger.info(metadata)
  end

  if macro_exported?(Logger, :warning, 2) do
    @doc """
    Logs `message` at `:warning` level with the formatted prefix.

    Pipeline: `prefix |> format_message(message, opts) |> Logger.warning(metadata)`.

    On Elixir versions where `Logger.warning/2` is not exported, this
    function instead forwards to `Logger.warn/2`. Both branches are
    selected at compile time.

    ## Parameters

      - `prefix` - `binary()`. Forwarded to the formatter.
      - `message` - `binary()`. Forwarded to the formatter.
      - `metadata` - `keyword()`. Default `[]`. Forwarded verbatim.
      - `opts` - `keyword()`. Default `[]`. Recognised key:
        `:format_message` (2-arity function).

    ## Returns

    `:ok`. The result of `Logger.warning/2` (or `Logger.warn/2` on
    older runtimes). The visible effect is a log entry at `:warning`
    level when the configured `Logger` level permits.

    ## Raises

      - `ArgumentError` - if `opts[:format_message]` is a function
        whose arity is not 2.

    ## Examples

        ExUtils.Logger.warning("App", "careful")
        # => emits "[App] careful" at :warning

    """
    @spec warning(
            prefix :: binary(),
            message :: binary(),
            metadata :: keyword(),
            opts :: keyword()
          ) :: :ok
    def warning(prefix, message, metadata \\ [], opts \\ []) do
      prefix
      |> format_message(message, opts)
      |> Logger.warning(metadata)
    end
  else
    @doc """
    Logs `message` at `:warning` level with the formatted prefix.

    On this runtime `Logger.warning/2` is not exported, so the
    function forwards to `Logger.warn/2`. Behaviour is otherwise
    identical to the `Logger.warning/2` branch.

    ## Parameters / Returns / Raises / Examples

    See the `Logger.warning/2` branch above (selected at compile time).
    """
    @spec warning(
            prefix :: binary(),
            message :: binary(),
            metadata :: keyword(),
            opts :: keyword()
          ) :: :ok
    def warning(prefix, message, metadata \\ [], opts \\ []) do
      prefix
      |> format_message(message, opts)
      |> Logger.warn(metadata)
    end
  end

  @doc """
  Logs `message` at `:error` level with the formatted prefix.

  Pipeline: `prefix |> format_message(message, opts) |> Logger.error(metadata)`.

  ## Parameters

    - `prefix` - `binary()`. Forwarded to the formatter.
    - `message` - `binary()`. Forwarded to the formatter.
    - `metadata` - `keyword()`. Default `[]`. Forwarded verbatim to
      `Logger.error/2`.
    - `opts` - `keyword()`. Default `[]`. Recognised key:
      `:format_message` (2-arity function). Other keys are ignored.

  ## Returns

  `:ok`. Whatever `Logger.error/2` returns. The visible effect is a
  log entry at `:error` level when the configured `Logger` level
  permits.

  ## Raises

    - `ArgumentError` - if `opts[:format_message]` is a function whose
      arity is not 2.

  ## Examples

      ExUtils.Logger.error("App", "boom")
      # => emits "[App] boom" at :error

  """
  @spec error(prefix :: binary(), message :: binary(), metadata :: keyword(), opts :: keyword()) ::
          :ok
  def error(prefix, message, metadata \\ [], opts \\ []) do
    prefix
    |> format_message(message, opts)
    |> Logger.error(metadata)
  end

  defp format_message(prefix, message, opts) do
    case opts[:format_message] do
      fun when is_function(fun, 2) ->
        fun.(prefix, message)

      fun when is_function(fun) ->
        raise ArgumentError, "format_message function must accept 2 arguments"

      _ ->
        "[#{prefix}] #{message}"
    end
  end
end
