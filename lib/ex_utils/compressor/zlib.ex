defmodule ExUtils.Compressor.ZLib do
  @moduledoc """
  A zlib-based compression adapter.

  Wraps Erlang's `:zlib` module behind the `ExUtils.Compressor.Adapter` contract,
  selecting between gzip-wrapped deflate (`:gzip` true, the default) and raw
  zlib deflate (`:gzip` false). The module is stateless: each call opens,
  uses, and closes its own zlib stream when needed.

  ## Responsibilities

    - Compress a binary as gzip or raw zlib (`compress/2`).
    - Decompress the matching codec (`decompress/2`).
    - Honour `:compression_level` (0..9) on the raw zlib path only.
    - Conform to `ExUtils.Compressor.Adapter` so `ExUtils.Compressor` can route to it.

  ## Examples

      iex> compressed = ExUtils.Compressor.ZLib.compress("hello world", [])
      iex> ExUtils.Compressor.ZLib.decompress(compressed, [])
      "hello world"

      iex> compressed = ExUtils.Compressor.ZLib.compress("hello", gzip: false, compression_level: 1)
      iex> ExUtils.Compressor.ZLib.decompress(compressed, gzip: false)
      "hello"

  """

  @behaviour ExUtils.Compressor.Adapter

  # Abstraction Function:
  #   The module represents a stateless, parameterised codec: a pair of
  #   inverse maps over `binary()` selected by `opts[:gzip]`.
  #     `gzip: true`  -> gzip-framed deflate (`:zlib.gzip`/`:zlib.gunzip`).
  #     `gzip: false` -> raw zlib deflate (`:zlib.deflate`/`:zlib.uncompress`)
  #                      at level `opts[:compression_level]` (default 9).
  #   `@default_gzip` represents the implicit codec when `:gzip` is absent.
  #   `@default_compression_level` represents the implicit level when
  #   `:compression_level` is absent on the raw zlib path.
  #   The transient `:zlib` port opened in `compress_zlib/2` is an ephemeral
  #   encoding session, not part of the module's abstract value -- it is
  #   created and torn down within a single call.
  #
  # Data Invariant:
  #   1. `gzip?(opts)` defaults to `true` when `:gzip` is absent.
  #   2. `:compression_level` is consulted only on the `gzip: false` path;
  #      the gzip path ignores it.
  #   3. Every `:zlib.open/0` is paired with `deflateEnd` and `close` on the
  #      same call -- no zlib port outlives a function call.
  #   4. `compress/2`'s output binds to the codec selected by `opts[:gzip]`;
  #      `decompress/2` recovers the input only when called with a matching
  #      `opts[:gzip]`.
  #   5. Both callbacks require a binary first argument and a keyword-list
  #      `opts` (enforced by the `is_binary` and `is_list` guards).
  #
  # Commutative Diagram (round-trip with matching opts):
  #
  #   content  --compress(opts)-->  compressed
  #      ^                              |
  #      |                              |
  #      +-------decompress(opts)-------+
  #
  #   For any `content :: binary()` and any `opts` such that
  #   `Keyword.get(opts, :gzip, true)` matches at both calls, the loop
  #   returns `content`.

  @default_compression_level 9
  @default_gzip true

  @doc """
  Returns `content` compressed via Erlang `:zlib`.

  The codec is selected by `opts[:gzip]`:

    - `true` (default) - gzip-wrapped deflate (`:zlib.gzip/1`). Decompressible
      by any gzip reader. `:compression_level` is ignored.
    - `false` - raw zlib deflate at level `opts[:compression_level]`
      (default 9). Decompress with `:zlib.uncompress/1` or this module's
      `decompress/2` with `gzip: false`.

  ## Parameters

    - `content` - `binary()`. The bytes to compress.
    - `opts` - `keyword()`. Recognised keys: `:gzip` (boolean, default
      `true`); `:compression_level` (integer 0..9, default 9, only consulted
      when `:gzip` is `false`). Other keys are ignored.

  ## Returns

  `binary()`. Compressed output. Empty input produces a valid empty-stream
  encoding. The output of the gzip path is not a valid raw-zlib stream and
  vice versa - decompress with the matching `:gzip` setting.

  ## Raises

    - `FunctionClauseError` - if `content` is not a binary or `opts` is not
      a keyword list.
    - `ErlangError` - if `:zlib` rejects the compression level when
      `gzip: false` (e.g. an integer outside 0..9).

  ## Examples

      iex> compressed = ExUtils.Compressor.ZLib.compress("hello world", [])
      iex> ExUtils.Compressor.ZLib.decompress(compressed, [])
      "hello world"

      iex> compressed = ExUtils.Compressor.ZLib.compress("hello", gzip: false, compression_level: 1)
      iex> ExUtils.Compressor.ZLib.decompress(compressed, gzip: false)
      "hello"

  """
  @impl true
  @spec compress(binary(), keyword()) :: binary()
  def compress(content, opts) when is_binary(content) and is_list(opts) do
    if gzip?(opts) do
      compress_gzip(content)
    else
      compress_zlib(content, opts)
    end
  end

  @doc """
  Returns the original bytes recovered from `compressed` via Erlang `:zlib`.

  The codec must match the one used at compression time:

    - `gzip: true` (default) - `:zlib.gunzip/1`.
    - `gzip: false` - `:zlib.uncompress/1` (raw zlib).

  ## Parameters

    - `compressed` - `binary()`. Output of `compress/2`.
    - `opts` - `keyword()`. Recognised keys: `:gzip` (boolean, default
      `true`). Other keys are ignored.

  ## Returns

  `binary()`. The decompressed bytes.

  ## Raises

    - `FunctionClauseError` - if `compressed` is not a binary or `opts` is
      not a keyword list.
    - `ErlangError` - if `compressed` is not a valid stream for the codec
      selected by `opts[:gzip]` (e.g. gzip data decompressed with
      `gzip: false`, or corrupted input).

  ## Examples

      iex> "hello"
      ...> |> ExUtils.Compressor.ZLib.compress([])
      ...> |> ExUtils.Compressor.ZLib.decompress([])
      "hello"

  """
  @impl true
  @spec decompress(binary(), keyword()) :: binary()
  def decompress(compressed, opts) when is_binary(compressed) and is_list(opts) do
    if gzip?(opts) do
      decompress_gzip(compressed)
    else
      decompress_zlib(compressed)
    end
  end

  defp compress_zlib(content, opts) do
    level = opts[:compression_level] || @default_compression_level
    z = :zlib.open()
    :zlib.deflateInit(z, level)
    iodata = :zlib.deflate(z, content, :finish)
    :zlib.deflateEnd(z)
    :zlib.close(z)
    IO.iodata_to_binary(iodata)
  end

  defp decompress_zlib(compressed) do
    :zlib.uncompress(compressed)
  end

  defp compress_gzip(content) do
    :zlib.gzip(content)
  end

  defp decompress_gzip(compressed) do
    :zlib.gunzip(compressed)
  end

  defp gzip?(opts) do
    Keyword.get(opts, :gzip, @default_gzip)
  end
end
