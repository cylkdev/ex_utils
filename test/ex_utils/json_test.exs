defmodule ExUtils.JSONTest do
  use ExUnit.Case, async: true
  doctest ExUtils.JSON

  alias ExUtils.JSON

  defmodule SampleStruct do
    @moduledoc false
    defstruct [:a, :b]
  end

  describe "to_jsonable_term/2 with pids" do
    test "registered local pid renders as inspect_string and registered name" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      Process.register(pid, :term_normalizer_test_named_pid)

      assert JSON.to_jsonable_term(pid, []) === "#{inspect(pid)}__term_normalizer_test_named_pid"

      Process.exit(pid, :kill)
    end

    test "unregistered local pid renders as inspect_string only" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      assert JSON.to_jsonable_term(pid, []) === inspect(pid)
      Process.exit(pid, :kill)
    end

    test "dead pid renders as inspect_string only" do
      pid = spawn(fn -> :ok end)

      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        500 -> flunk("process did not exit in time")
      end

      assert JSON.to_jsonable_term(pid, []) === inspect(pid)
    end
  end

  describe "to_jsonable_term/2 with date" do
    test "default format is extended ISO 8601" do
      assert JSON.to_jsonable_term(~D[2026-05-02], []) === "2026-05-02"
    end

    test "explicit basic format respected" do
      assert JSON.to_jsonable_term(~D[2026-05-02], date: [format: :basic]) === "20260502"
    end
  end

  describe "to_jsonable_term/2 with time" do
    test "default format is extended ISO 8601" do
      assert JSON.to_jsonable_term(~T[12:34:56], []) === "12:34:56"
    end

    test "explicit basic format respected" do
      assert JSON.to_jsonable_term(~T[12:34:56], time: [format: :basic]) === "123456"
    end
  end

  describe "to_jsonable_term/2 with datetime" do
    test "default format is extended ISO 8601" do
      assert JSON.to_jsonable_term(~U[2026-05-02 12:34:56Z], []) === "2026-05-02T12:34:56Z"
    end

    test "explicit basic format respected" do
      assert JSON.to_jsonable_term(~U[2026-05-02 12:34:56Z], datetime: [format: :basic]) ===
               "20260502T123456Z"
    end
  end

  describe "to_jsonable_term/2 with naive datetime" do
    test "default format is extended ISO 8601" do
      assert JSON.to_jsonable_term(~N[2026-05-02 12:34:56], []) === "2026-05-02T12:34:56"
    end

    test "explicit basic format respected" do
      assert JSON.to_jsonable_term(~N[2026-05-02 12:34:56], datetime: [format: :basic]) ===
               "20260502T123456"
    end
  end

  describe "to_jsonable_term/2 with generic structs" do
    test "returns a map with struct name (Elixir. stripped) and data" do
      assert JSON.to_jsonable_term(%SampleStruct{a: 1, b: 2}, []) ===
               %{struct: "ExUtils.JSONTest.SampleStruct", data: %{a: 1, b: 2}}
    end
  end

  describe "to_jsonable_term/2 with functions" do
    test "named-function reference returns module, function, and arity" do
      assert JSON.to_jsonable_term(&String.upcase/1, []) ===
               %{module: "Elixir.String", function: "upcase", arity: 1}
    end
  end

  describe "to_jsonable_term/2 with primitives passes through unchanged" do
    test "binaries" do
      assert JSON.to_jsonable_term("abc", []) === "abc"
    end

    test "integers" do
      assert JSON.to_jsonable_term(42, []) === 42
    end

    test "floats" do
      assert JSON.to_jsonable_term(1.5, []) === 1.5
    end

    test "atoms" do
      assert JSON.to_jsonable_term(:foo, []) === :foo
    end

    test "booleans" do
      assert JSON.to_jsonable_term(true, []) === true
      assert JSON.to_jsonable_term(false, []) === false
    end

    test "nil" do
      assert JSON.to_jsonable_term(nil, []) === nil
    end
  end

  describe "decode/1" do
    test "returns string-keyed maps by default" do
      assert JSON.decode(~s({"someKey": 1})) === %{"someKey" => 1}
    end

    test "decodes nested structures with string keys" do
      assert JSON.decode(~s({"a": 1, "nested": {"b": 2}})) === %{
               "a" => 1,
               "nested" => %{"b" => 2}
             }
    end
  end

  describe "decode/2 default behavior (no atomize_keys)" do
    test "preserves string keys when atomize_keys is omitted" do
      assert JSON.decode(~s({"someKey": 1}), []) === %{"someKey" => 1}
    end

    test "preserves string keys when atomize_keys: false" do
      assert JSON.decode(~s({"someKey": 1}), atomize_keys: false) === %{"someKey" => 1}
    end
  end

  describe "decode/2 with atomize_keys: true" do
    test "converts string keys to existing atoms by default" do
      # Pre-create the atom so to_existing_atom: true (default) succeeds.
      _ = :decode2_existing_atom_key
      json = ~s({"decode2_existing_atom_key": 1})
      assert JSON.decode(json, atomize_keys: true) === %{decode2_existing_atom_key: 1}
    end

    test "raises ArgumentError when atom does not yet exist (default to_existing_atom: true)" do
      json = ~s({"definitely_not_an_existing_atom_xyz_qqq_123": 1})

      assert_raise ArgumentError, fn ->
        JSON.decode(json, atomize_keys: true)
      end
    end

    test "strict + allowed_keys list permits matching keys when minting new atoms" do
      json = ~s({"json_decode2_new_atom": 1})

      assert JSON.decode(json,
               atomize_keys: true,
               to_existing_atom: false,
               strict: true,
               allowed_keys: ["json_decode2_new_atom"]
             ) === %{json_decode2_new_atom: 1}
    end

    test "strict + allowed_keys MapSet works the same as list" do
      json = ~s({"json_decode2_mapset": 1})

      assert JSON.decode(json,
               atomize_keys: true,
               to_existing_atom: false,
               strict: true,
               allowed_keys: MapSet.new(["json_decode2_mapset"])
             ) === %{json_decode2_mapset: 1}
    end

    test "raises when allowed_keys nil + strict true + to_existing_atom false" do
      json = ~s({"someKey": 1})

      assert_raise RuntimeError, ~r/allowed_keys must be provided when :strict is true/, fn ->
        JSON.decode(json,
          atomize_keys: true,
          to_existing_atom: false,
          strict: true,
          allowed_keys: nil
        )
      end
    end

    test "raises when key not in allowed_keys + strict true" do
      json = ~s({"bar": 1})

      assert_raise RuntimeError, ~r/Key not allowed: bar/, fn ->
        JSON.decode(json,
          atomize_keys: true,
          to_existing_atom: false,
          strict: true,
          allowed_keys: ["foo"]
        )
      end
    end

    test "strict: false with no allowed_keys mints atoms freely" do
      json = ~s({"json_decode2_freely_minted": 1})

      result =
        JSON.decode(json,
          atomize_keys: true,
          to_existing_atom: false,
          strict: false,
          allowed_keys: nil
        )

      assert result === %{json_decode2_freely_minted: 1}
    end

    test "recursively atomizes through nested map → nested map" do
      _ = :decode2_outer
      _ = :decode2_inner
      json = ~s({"decode2_outer": {"decode2_inner": 7}})

      assert JSON.decode(json, atomize_keys: true) === %{
               decode2_outer: %{decode2_inner: 7}
             }
    end

    test "recursively atomizes through nested map → list → map" do
      _ = :decode2_items
      _ = :decode2_id
      _ = :decode2_name
      json = ~s({"decode2_items": [{"decode2_id": 1, "decode2_name": "a"}]})

      assert JSON.decode(json, atomize_keys: true) === %{
               decode2_items: [%{decode2_id: 1, decode2_name: "a"}]
             }
    end

    test "does NOT recase keys (camelCase atom keys preserved)" do
      _ = :someCamelKey
      json = ~s({"someCamelKey": 1})
      assert JSON.decode(json, atomize_keys: true) === %{someCamelKey: 1}
    end

    test "leaf values are passed through unchanged" do
      _ = :decode2_a
      _ = :decode2_b
      json = ~s({"decode2_a": "string", "decode2_b": [1, 2.5, true, null]})

      assert JSON.decode(json, atomize_keys: true) === %{
               decode2_a: "string",
               decode2_b: [1, 2.5, true, nil]
             }
    end
  end

end
