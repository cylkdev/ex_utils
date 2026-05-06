if Code.ensure_loaded?(:zstd) do
  defmodule ExUtils.Compressor.ZStd do
    @moduledoc """
    A zstd-based compression adapter.

    Wraps Erlang/OTP's `:zstd` module behind the `ExUtils.Compressor.Adapter`
    contract. Available only when `:zstd` can be loaded at compile time
    (OTP 28+ ships it in stdlib; earlier OTP versions need a third-party
    dependency). When unavailable, this module compiles in a fallback that
    raises `RuntimeError` from both callbacks.

    ## Responsibilities

      - Compress a binary into a zstd frame (`compress/2`).
      - Decompress a zstd frame (`decompress/2`).
      - Apply encoder defaults (`compressionLevel: 9`, `checksumFlag: true`,
        `contentSizeFlag: true`) and let callers override via `opts`.
      - Conform to `ExUtils.Compressor.Adapter` so `ExUtils.Compressor` can route to it.

    ## Examples

        # Round-trip (only succeeds when :zstd is available).
        # iex> compressed = ExUtils.Compressor.ZStd.compress("hello", [])
        # iex> ExUtils.Compressor.ZStd.decompress(compressed, [])
        # "hello"

    """

    @behaviour ExUtils.Compressor.Adapter

    # Abstraction Function:
    #   The module represents a stateless zstd codec: a pair of inverse maps
    #   over `binary()`. `compress/2` is the forward map; `decompress/2` is
    #   its inverse. `@default_options` represents the encoder defaults that
    #   are applied before forwarding to `:zstd.compress/2`; caller-supplied
    #   keys in `opts` override them.
    #
    # Data Invariant:
    #   1. The `:zstd` Erlang module is loadable at compile time -- the
    #      `Code.ensure_loaded?(:zstd)` guard at the top of the file selects
    #      this definition; the `else` branch defines a raising fallback.
    #   2. Encoder options forwarded to `:zstd.compress/2` are
    #      `Keyword.merge(@default_options, opts)`, so caller keys win over
    #      defaults.
    #   3. `compress/2`'s output is a valid zstd frame.
    #   4. `decompress/2` ignores `opts` (kept solely for behaviour
    #      conformance with `ExUtils.Compressor.Adapter`).
    #   5. Both callbacks coerce `:zstd`'s iodata output to a single binary
    #      via `IO.iodata_to_binary/1`.
    #
    # Commutative Diagram (round-trip):
    #
    #   content  --compress(opts)-->  zstd_frame
    #      ^                               |
    #      |                               |
    #      +-------decompress(opts)--------+

    @default_options [
      compressionLevel: 9,
      checksumFlag: true,
      contentSizeFlag: true
    ]

    @doc """
    Returns `content` compressed with zstd.

    Available only when the Erlang `:zstd` module is loaded (OTP 28+ ships it
    in stdlib; earlier OTP versions need a third-party dep). When unavailable,
    this function raises - see "Raises" below.

    When available, defaults are merged with `opts` and forwarded to
    `:zstd.compress/2`:

      - `compressionLevel: 9`
      - `checksumFlag: true`
      - `contentSizeFlag: true`

    Caller-supplied keys in `opts` override the defaults.

    ## Parameters

      - `content` - `binary()`. The bytes to compress.
      - `opts` - `keyword()`. Forwarded to `:zstd.compress/2` after merging
        the defaults above.

    ## Returns

    `binary()`. Compressed zstd frame.

    ## Raises

      - `RuntimeError` - if the `:zstd` module is not loaded at compile time
        (message: `"zstd dependency not available. OTP version 28+ required, got: <release>"`).
      - `FunctionClauseError` - if `content` is not a binary or `opts` is not
        a keyword list (only when `:zstd` is available; the unavailable
        fallback raises `RuntimeError` regardless).
      - `ErlangError` - if `:zstd.compress/2` rejects the merged options.

    ## Examples

        # Round-trip (only succeeds when :zstd is available).
        # iex> compressed = ExUtils.Compressor.ZStd.compress("hello", [])
        # iex> ExUtils.Compressor.ZStd.decompress(compressed, [])
        # "hello"

    """
    @impl true
    @spec compress(binary(), keyword()) :: binary()
    def compress(content, opts) when is_binary(content) and is_list(opts) do
      content
      |> :zstd.compress(Keyword.merge(@default_options, opts))
      |> IO.iodata_to_binary()
    end

    @doc """
    Returns the original bytes recovered from a zstd frame.

    Available only when the Erlang `:zstd` module is loaded. When unavailable,
    this function raises - see "Raises" below.

    ## Parameters

      - `compressed` - `binary()`. A zstd-compressed frame produced by
        `compress/2` or any compatible zstd encoder.
      - `opts` - `keyword()`. Accepted for adapter-behaviour conformance.

    ## Returns

    `binary()`. The decompressed bytes.

    ## Raises

      - `RuntimeError` - if the `:zstd` module is not loaded at compile time.
      - `FunctionClauseError` - if `compressed` is not a binary or `opts` is
        not a keyword list (only when `:zstd` is available).
      - `ErlangError` - if `compressed` is not a valid zstd frame.

    ## Examples

        # Round-trip (only succeeds when :zstd is available).
        # iex> "hello"
        # ...> |> ExUtils.Compressor.ZStd.compress([])
        # ...> |> ExUtils.Compressor.ZStd.decompress([])
        # "hello"

    """
    @impl true
    @spec decompress(binary(), keyword()) :: binary()
    def decompress(compressed, opts) when is_binary(compressed) and is_list(opts) do
      _ = opts

      compressed
      |> :zstd.decompress()
      |> IO.iodata_to_binary()
    end
  end
else
  defmodule ExUtils.Compressor.ZStd do
    @moduledoc false

    @behaviour ExUtils.Compressor.Adapter

    @otp_release System.otp_release()

    @impl true
    def compress(_content, _opts) do
      raise "zstd dependency not available. OTP version 28+ required, got: #{@otp_release}"
    end

    @impl true
    def decompress(_compressed, _opts) do
      raise "zstd dependency not available. OTP version 28+ required, got: #{@otp_release}"
    end
  end
end
