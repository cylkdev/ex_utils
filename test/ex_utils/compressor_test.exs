defmodule ExUtils.CompressorTest do
  use ExUnit.Case, async: true

  alias ExUtils.Compressor

  defmodule StubAdapter do
    @moduledoc false
    @behaviour ExUtils.Compressor.Adapter

    @impl true
    def compress(content, opts) do
      send(self(), {:stub_compress, content, opts})
      <<"stub_compressed:", content::binary>>
    end

    @impl true
    def decompress(compressed, opts) do
      send(self(), {:stub_decompress, compressed, opts})
      <<"stub_decompressed:", compressed::binary>>
    end
  end

  describe "compress/2 and decompress/2 default adapter (no opts)" do
    test "round-trips a binary using the default ZLib (gzip) adapter" do
      original = "default-adapter content"
      compressed = Compressor.compress(original, [])

      assert is_binary(compressed)
      assert compressed !== original
      assert Compressor.decompress(compressed, []) === original
    end
  end

  describe "compress/2 and decompress/2 routing via :compression_algorithm" do
    test ":zlib routes to ExUtils.Compressor.ZLib" do
      original = "zlib-routed content"
      compressed = Compressor.compress(original, compression_algorithm: :zlib)

      # Default ZLib path uses gzip; gzip data starts with 0x1f, 0x8b.
      assert <<0x1F, 0x8B, _rest::binary>> = compressed
      assert Compressor.decompress(compressed, compression_algorithm: :zlib) === original
    end

    test ":zstd routes to ExUtils.Compressor.ZStd which raises on this OTP build" do
      assert_raise RuntimeError, ~r/zstd dependency not available/, fn ->
        Compressor.compress("anything", compression_algorithm: :zstd)
      end

      assert_raise RuntimeError, ~r/zstd dependency not available/, fn ->
        Compressor.decompress("anything", compression_algorithm: :zstd)
      end
    end
  end

  describe "compress/2 and decompress/2 with :compression_module override" do
    test ":compression_module overrides :compression_algorithm" do
      result =
        Compressor.compress("payload",
          compression_module: StubAdapter,
          compression_algorithm: :zlib
        )

      assert result === "stub_compressed:payload"
      assert_received {:stub_compress, "payload", _opts}
    end

    test ":compression_module overrides the default adapter when no algorithm given" do
      result = Compressor.compress("payload", compression_module: StubAdapter)

      assert result === "stub_compressed:payload"
      assert_received {:stub_compress, "payload", _opts}
    end

    test ":compression_module is used by decompress/2 as well" do
      result = Compressor.decompress("blob", compression_module: StubAdapter)

      assert result === "stub_decompressed:blob"
      assert_received {:stub_decompress, "blob", _opts}
    end

    test "forwards the full opts list through to the adapter" do
      opts = [compression_module: StubAdapter, extra: :flag, compression_level: 3]
      Compressor.compress("payload", opts)

      assert_received {:stub_compress, "payload", forwarded_opts}
      assert forwarded_opts === opts
    end
  end
end
