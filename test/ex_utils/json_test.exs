defmodule ExUtils.JSONTest do
  use ExUnit.Case, async: true

  alias ExUtils.JSON

  describe "decode/2 — happy paths" do
    test "decodes a JSON object" do
      assert {:ok, %{"a" => 1, "b" => "two"}} = JSON.decode(~s({"a":1,"b":"two"}))
    end

    test "decodes a JSON array" do
      assert {:ok, [1, 2, 3]} = JSON.decode("[1,2,3]")
    end

    test "decodes a scalar" do
      assert {:ok, 42} = JSON.decode("42")
      assert {:ok, "hello"} = JSON.decode(~s("hello"))
    end
  end

  describe "decode/2 — :atomize_keys" do
    test "atomizes binary keys on a flat map" do
      _ = :json_test_a
      _ = :json_test_b

      assert {:ok, %{json_test_a: 1, json_test_b: 2}} =
               JSON.decode(~s({"json_test_a":1,"json_test_b":2}),
                 atomize_keys: true,
                 to_existing_atom: true
               )
    end

    test "atomizes keys on nested maps" do
      _ = :json_test_outer
      _ = :json_test_inner

      assert {:ok, %{json_test_outer: %{json_test_inner: 1}}} =
               JSON.decode(~s({"json_test_outer":{"json_test_inner":1}}),
                 atomize_keys: true,
                 to_existing_atom: true
               )
    end

    test "atomizes keys traversing through lists" do
      _ = :json_test_list_key

      assert {:ok, [%{json_test_list_key: 1}, %{json_test_list_key: 2}]} =
               JSON.decode(~s([{"json_test_list_key":1},{"json_test_list_key":2}]),
                 atomize_keys: true,
                 to_existing_atom: true
               )
    end

    test ":null becomes nil after atomize_keys" do
      _ = :json_test_null_key

      assert {:ok, %{json_test_null_key: nil}} =
               JSON.decode(~s({"json_test_null_key":null}),
                 atomize_keys: true,
                 to_existing_atom: true
               )
    end

    test "custom :decoders branch + atomize_keys: outer 3-tuple is opaque to the walker" do
      # When :decoders is supplied, JSON.decode/3 returns {value, acc, rest}.
      # The walker has no clause for 3-tuples, so it returns the term as-is
      # (the catchall) and does NOT recurse into the inner map.
      result =
        JSON.decode(~s({"k":null}),
          decoders: [],
          atomize_keys: true,
          to_existing_atom: true
        )

      assert {%{"k" => nil}, [], ""} = result
    end

    test "the {:ok, _} 2-tuple wrapper exercises the tuple branch of the walker" do
      # JSON.decode/1 returns {:ok, value}; the atomize walker recurses into
      # 2-tuples, so the :ok atom flows through `atomize_key/2`'s non-binary
      # clause.
      _ = :json_test_tuple_branch

      assert {:ok, %{json_test_tuple_branch: 1}} =
               JSON.decode(~s({"json_test_tuple_branch":1}),
                 atomize_keys: true,
                 to_existing_atom: true
               )
    end
  end

  describe "decode/2 — atom safety options forwarded to ExUtils.Strings" do
    test ":to_existing_atom raises on unknown key (caught and returned as :bad_json)" do
      assert {:error, :bad_json} =
               JSON.decode(~s({"json_unknown_atom_xyz_qqq":1}),
                 atomize_keys: true,
                 to_existing_atom: true
               )
    end

    test ":strict + :allowed_keys mints listed keys" do
      assert {:ok, %{json_test_minted_strict: 1}} =
               JSON.decode(~s({"json_test_minted_strict":1}),
                 atomize_keys: true,
                 to_existing_atom: false,
                 strict: true,
                 allowed_keys: ["json_test_minted_strict"]
               )
    end

    test ":strict + key not in :allowed_keys returns {:error, :bad_json}" do
      assert {:error, :bad_json} =
               JSON.decode(~s({"json_disallowed":1}),
                 atomize_keys: true,
                 to_existing_atom: false,
                 strict: true,
                 allowed_keys: ["only_this"]
               )
    end
  end

  describe "decode/2 — :decoders branch" do
    test "passes :decoders option through to JSON.decode/3 with explicit :accumulator" do
      # Empty decoders list uses stdlib defaults; result shape from JSON.decode/3
      # is {value, accumulator, rest}.
      assert {[1, 2, 3], :acc_seed, ""} =
               JSON.decode("[1,2,3]", decoders: [], accumulator: :acc_seed)
    end

    test ":decoders branch with no :accumulator opt defaults to []" do
      assert {[1, 2], [], ""} = JSON.decode("[1,2]", decoders: [])
    end
  end

  describe "decode/2 — invalid JSON" do
    test "returns the raw {:error, _} tuple from JSON.decode on malformed input" do
      assert {:error, _} = JSON.decode("not json")
    end

    test "returns the raw {:error, _} tuple from JSON.decode on empty string" do
      assert {:error, _} = JSON.decode("")
    end

    test "returns {:error, :bad_json} when atomize_keys raises (rescue branch)" do
      # to_existing_atom raises ArgumentError for unknown atoms; the rescue
      # converts that to {:error, :bad_json}.
      assert {:error, :bad_json} =
               JSON.decode(~s({"json_unknown_atom_zzz_qqq_xyz":1}),
                 atomize_keys: true,
                 to_existing_atom: true
               )
    end
  end

  describe "encode!/2" do
    test "encodes a map" do
      assert JSON.encode!(%{"a" => 1}) === ~s({"a":1})
    end

    test "encodes nil via JSON.encode!/1" do
      assert JSON.encode!(nil) === "null"
    end

    test "to_iodata: true with default encoder produces iodata" do
      result = JSON.encode!(%{"a" => 1}, to_iodata: true)
      assert IO.iodata_to_binary(result) === ~s({"a":1})
    end

    test "to_iodata: true with custom :encoder uses the supplied encoder" do
      encoder = &Elixir.JSON.protocol_encode/2
      result = JSON.encode!(%{"a" => 1}, to_iodata: true, encoder: encoder)
      assert IO.iodata_to_binary(result) === ~s({"a":1})
    end

    test "to_iodata: false (default) falls through to JSON.encode!/1" do
      assert JSON.encode!(%{"a" => 1}, to_iodata: false) === ~s({"a":1})
    end
  end
end
