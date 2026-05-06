defmodule ExUtils.Compressor do
  @moduledoc """
  A routing facade for binary compression.

  Picks an adapter from the caller's `opts` and forwards the call. Adapter
  implementations live in sibling modules (`ExUtils.Compressor.ZLib`,
  `ExUtils.Compressor.ZStd`) and conform to `ExUtils.Compressor.Adapter`.
  The module is stateless: every call resolves the adapter fresh from the
  supplied options.

  ## Responsibilities

    - Compress a binary using a caller-selected adapter (`compress/2`).
    - Decompress a binary using the same adapter (`decompress/2`).
    - Resolve which adapter to use from `opts` in a fixed priority order:
      `:compression_module` over `:compression_algorithm` over the default
      adapter (`ExUtils.Compressor.ZLib`).
    - Forward `opts` to the adapter unchanged so adapter-specific keys
      (e.g. `:gzip`, `:compression_level`, `:compressionLevel`) pass
      through.

  ## Examples

      iex> compressed = ExUtils.Compressor.compress("hello", [])
      iex> ExUtils.Compressor.decompress(compressed, [])
      "hello"

      iex> compressed = ExUtils.Compressor.compress("hello", compression_algorithm: :zlib, gzip: false)
      iex> ExUtils.Compressor.decompress(compressed, compression_algorithm: :zlib, gzip: false)
      "hello"

  """

  # Abstraction Function:
  #   The private `adapter/1` represents the resolution rule that maps an
  #   `opts` keyword list to the adapter module that will service the
  #   call. `@default_adapter` represents the fallback used when `opts`
  #   does not pin an adapter. The module itself has no persistent state;
  #   the abstraction is a stateless function `(opts, content) -> binary`
  #   that delegates to the resolved adapter.
  #
  # Data Invariant:
  #   1. `adapter(opts)` is deterministic in `opts`.
  #   2. Resolution priority is fixed: `opts[:compression_module]` wins
  #      over the result of mapping `opts[:compression_algorithm]`, which
  #      wins over `@default_adapter`.
  #   3. `opts[:compression_algorithm]`, when present, is one of `nil`,
  #      `:zlib`, `:zstd`; any other value raises `CaseClauseError` at
  #      the inner case clause.
  #   4. The resolved module is expected to implement
  #      `ExUtils.Compressor.Adapter`. The resolution code does not check
  #      this; failure surfaces as an `UndefinedFunctionError` from the
  #      adapter call.
  #   5. `compress/2` and `decompress/2` resolve through the same rule,
  #      so identical `opts` route both directions to the same adapter.
  #
  # Commutative Diagram (compress dispatch):
  #
  #   (content, opts)  --ExUtils.Compressor.compress-->  compressed
  #         |                                              ^
  #         | adapter(opts)                                |
  #         v                                              |
  #     adapter_module --compress(content, opts)-----------+

  @default_adapter ExUtils.Compressor.ZLib

  @doc """
  Returns `content` compressed by the adapter selected from `opts`.

  Adapter selection order:

    1. `opts[:compression_module]` if set (any module exporting
       `compress/2`).
    2. `opts[:compression_algorithm]` mapped to a built-in adapter:
       `:zlib` -> `ExUtils.Compressor.ZLib`,
       `:zstd` -> `ExUtils.Compressor.ZStd`.
    3. Default: `ExUtils.Compressor.ZLib`.

  The full `opts` keyword list is forwarded to the adapter unchanged, so
  adapter-specific options (e.g. `:gzip`, `:compression_level`,
  `:compressionLevel`) pass through.

  ## Parameters

    - `content` - `binary()`. The bytes to compress. Forwarded unchanged
      to the adapter; this module does not validate content shape.
    - `opts` - `keyword()`. Routing keys (`:compression_module`,
      `:compression_algorithm`) plus any options the chosen adapter
      accepts.

  ## Returns

  `binary()`. The adapter's compressed output. Empty input is permitted;
  the adapter decides the encoded form. No global state is touched. The
  exact byte output depends on which adapter resolves.

  ## Raises

    - `CaseClauseError` - if `opts[:compression_algorithm]` is set to a
      value other than `nil`, `:zlib`, or `:zstd`.
    - `UndefinedFunctionError` - if `opts[:compression_module]` is a
      module that does not export `compress/2`.
    - Any exception the chosen adapter raises (e.g. `RuntimeError` from
      `ExUtils.Compressor.ZStd` when the `:zstd` dependency is
      unavailable).

  ## Examples

      # Default adapter is ZLib (gzip).
      iex> compressed = ExUtils.Compressor.compress("hello", [])
      iex> ExUtils.Compressor.decompress(compressed, [])
      "hello"

      # Explicit algorithm selection.
      iex> compressed = ExUtils.Compressor.compress("hello", compression_algorithm: :zlib, gzip: false)
      iex> ExUtils.Compressor.decompress(compressed, compression_algorithm: :zlib, gzip: false)
      "hello"

  """
  @spec compress(binary(), keyword()) :: binary()
  def compress(content, opts) do
    adapter(opts).compress(content, opts)
  end

  @doc """
  Returns the original bytes recovered from `compressed` by the adapter
  selected from `opts`.

  Adapter selection follows the same rules as `compress/2`. The same
  `opts` used at compression time should be passed at decompression time
  so the adapter routes to the matching codec (e.g. `:gzip` for ZLib).

  ## Parameters

    - `compressed` - `binary()`. Output of a prior `compress/2` call.
    - `opts` - `keyword()`. Routing keys (`:compression_module`,
      `:compression_algorithm`) plus any adapter-specific options.

  ## Returns

  `binary()`. The decompressed bytes as returned by the adapter. No
  global state is touched.

  ## Raises

    - `CaseClauseError` - if `opts[:compression_algorithm]` is set to a
      value other than `nil`, `:zlib`, or `:zstd`.
    - `UndefinedFunctionError` - if `opts[:compression_module]` is a
      module that does not export `decompress/2`.
    - Any exception the chosen adapter raises when `compressed` does not
      match the adapter or codec selected by `opts` (e.g. `ErlangError`
      from `ExUtils.Compressor.ZLib` when the `:gzip` flag does not
      match the data).

  ## Examples

      iex> "hello"
      ...> |> ExUtils.Compressor.compress(compression_algorithm: :zlib)
      ...> |> ExUtils.Compressor.decompress(compression_algorithm: :zlib)
      "hello"

  """
  @spec decompress(binary(), keyword()) :: binary()
  def decompress(compressed, opts) do
    adapter(opts).decompress(compressed, opts)
  end

  defp adapter(opts) do
    compression_module =
      case opts[:compression_algorithm] do
        nil -> nil
        :zlib -> ExUtils.Compressor.ZLib
        :zstd -> ExUtils.Compressor.ZStd
      end

    opts[:compression_module] || compression_module || @default_adapter
  end
end
