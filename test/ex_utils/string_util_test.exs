defmodule ExUtils.StringUtilTest do
  use ExUnit.Case, async: true
  doctest ExUtils.StringUtil

  alias ExUtils.StringUtil

  describe "string_to_atom/2" do
    test "to_existing_atom: true converts to existing atom" do
      _ = :safe_atom_existing_one
      assert StringUtil.string_to_atom("safe_atom_existing_one", to_existing_atom: true) ===
               :safe_atom_existing_one
    end

    test "to_existing_atom: true raises when atom does not exist" do
      assert_raise ArgumentError, fn ->
        StringUtil.string_to_atom("safe_atom_nonexistent_qqq_zzz", to_existing_atom: true)
      end
    end

    test "to_existing_atom: false + strict: true + allowed_keys list mints when allowed" do
      assert StringUtil.string_to_atom("safe_atom_minted_one",
               to_existing_atom: false,
               strict: true,
               allowed_keys: ["safe_atom_minted_one"]
             ) === :safe_atom_minted_one
    end

    test "to_existing_atom: false + strict: true + allowed_keys MapSet mints when allowed" do
      assert StringUtil.string_to_atom("safe_atom_minted_mapset",
               to_existing_atom: false,
               strict: true,
               allowed_keys: MapSet.new(["safe_atom_minted_mapset"])
             ) === :safe_atom_minted_mapset
    end

    test "to_existing_atom: false + strict: true + allowed_keys nil raises" do
      assert_raise RuntimeError, ~r/allowed_keys must be provided when :strict is true/, fn ->
        StringUtil.string_to_atom("anything",
          to_existing_atom: false,
          strict: true,
          allowed_keys: nil
        )
      end
    end

    test "to_existing_atom: false + strict: true rejects key not in allowed_keys" do
      assert_raise RuntimeError, ~r/Key not allowed: bar/, fn ->
        StringUtil.string_to_atom("bar",
          to_existing_atom: false,
          strict: true,
          allowed_keys: ["foo"]
        )
      end
    end

    test "to_existing_atom: false + strict: false mints freely even without allowed_keys" do
      assert StringUtil.string_to_atom("safe_atom_freely_minted_two",
               to_existing_atom: false,
               strict: false,
               allowed_keys: nil
             ) === :safe_atom_freely_minted_two
    end
  end
end
