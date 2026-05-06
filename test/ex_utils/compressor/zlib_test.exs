defmodule ExUtils.Compressor.ZLibTest do
  use ExUnit.Case, async: true

  alias ExUtils.Compressor.ZLib

  describe "compress/2 and decompress/2 with default opts (gzip on)" do
    test "round-trips a small binary using gzip by default" do
      original = "hello, gzip world"
      compressed = ZLib.compress(original, [])

      # gzip frames start with the magic bytes 0x1f, 0x8b
      assert <<0x1F, 0x8B, _rest::binary>> = compressed
      assert ZLib.decompress(compressed, []) === original
    end

    test "explicit gzip: true behaves the same as the default" do
      original = "hello, gzip world"
      compressed = ZLib.compress(original, gzip: true)

      assert <<0x1F, 0x8B, _rest::binary>> = compressed
      assert ZLib.decompress(compressed, gzip: true) === original
    end
  end

  describe "compress/2 and decompress/2 with gzip: false (raw zlib)" do
    test "round-trips a binary through raw zlib deflate/uncompress" do
      original = "hello, raw zlib"
      compressed = ZLib.compress(original, gzip: false)

      # Raw zlib output should differ from the gzip output for the same input,
      # confirming the gzip: false branch actually produced raw zlib data.
      gzipped = ZLib.compress(original, gzip: true)
      assert compressed !== gzipped

      assert ZLib.decompress(compressed, gzip: false) === original
    end

    test "honors :compression_level at level 1" do
      original = String.duplicate("compression-level-1 ", 100)
      compressed = ZLib.compress(original, gzip: false, compression_level: 1)

      assert ZLib.decompress(compressed, gzip: false) === original
    end

    test "honors :compression_level at level 9" do
      original = String.duplicate("compression-level-9 ", 100)
      compressed = ZLib.compress(original, gzip: false, compression_level: 9)

      assert ZLib.decompress(compressed, gzip: false) === original
    end
  end

  describe "compress/2 and decompress/2 mismatched gzip flag" do
    test "decompressing gzip data with gzip: false raises" do
      compressed = ZLib.compress("payload", gzip: true)

      assert_raise ErlangError, fn ->
        ZLib.decompress(compressed, gzip: false)
      end
    end
  end

  describe "compress/2 and decompress/2 boundary inputs" do
    test "empty binary round-trips through gzip" do
      assert ZLib.decompress(ZLib.compress("", []), []) === ""
    end

    test "empty binary round-trips through raw zlib" do
      assert ZLib.decompress(ZLib.compress("", gzip: false), gzip: false) === ""
    end

    test "larger repeating binary round-trips and compresses smaller than input" do
      original = String.duplicate("abcdefgh", 1_000)
      compressed = ZLib.compress(original, [])

      assert byte_size(compressed) < byte_size(original)
      assert ZLib.decompress(compressed, []) === original
    end

    test "larger repeating binary round-trips through raw zlib and compresses smaller" do
      original = String.duplicate("abcdefgh", 1_000)
      compressed = ZLib.compress(original, gzip: false)

      assert byte_size(compressed) < byte_size(original)
      assert ZLib.decompress(compressed, gzip: false) === original
    end
  end
end
