defmodule ExUtils.Compressor.ZStdTest do
  use ExUnit.Case, async: true

  # This project runs on OTP 27, where :zstd is not available.
  # The fallback module that raises is what gets compiled, and these tests
  # cover that behaviour. If/when this project upgrades to OTP 28+ and
  # :zstd is loaded, the conditionally-compiled real implementation will
  # supersede this fallback and these tests will need to be reworked.

  alias ExUtils.Compressor.ZStd

  describe "compress/2 fallback (no :zstd available)" do
    test "raises a RuntimeError mentioning the missing zstd dependency" do
      assert_raise RuntimeError, ~r/zstd dependency not available/, fn ->
        ZStd.compress("anything", [])
      end
    end

    test "raises regardless of the opts list contents" do
      assert_raise RuntimeError, ~r/zstd dependency not available/, fn ->
        ZStd.compress("anything", compressionLevel: 5)
      end
    end
  end

  describe "decompress/2 fallback (no :zstd available)" do
    test "raises a RuntimeError mentioning the missing zstd dependency" do
      assert_raise RuntimeError, ~r/zstd dependency not available/, fn ->
        ZStd.decompress("anything", [])
      end
    end

    test "raises regardless of the opts list contents" do
      assert_raise RuntimeError, ~r/zstd dependency not available/, fn ->
        ZStd.decompress("anything", some: :opt)
      end
    end
  end
end
