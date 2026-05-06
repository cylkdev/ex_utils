defmodule ExUtils.SerializerTest do
  use ExUnit.Case, async: true
  doctest ExUtils.Serializer

  alias ExUtils.Serializer

  defmodule TupleTransform do
    @moduledoc false
    def call(val), do: {:wrapped, val}
  end

  defmodule TupleDumper do
    @moduledoc false
    def dump(val, _opts), do: {:dumped, val}
  end

  defmodule CustomDumperModule do
    @moduledoc false
    def to_serial_term(val, _opts), do: {:custom_dumper, val}
  end

  defmodule NormalizeKeyModule do
    @moduledoc false
    def normalize_key("__skip__"), do: :__skipped__
    def normalize_key("@bad@"), do: 12_345
    def normalize_key(val) when is_binary(val), do: String.replace(val, "x_", "")
  end

  defmodule NoNormalizeKey do
    @moduledoc false
    def some_other_function, do: :ok
  end

  defmodule SampleStruct do
    @moduledoc false
    defstruct [:a, :b]
  end

  describe "to_serial_term/2 with pids" do
    test "registered local pid renders as inspect_string and registered name" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      Process.register(pid, :term_normalizer_test_named_pid)

      assert Serializer.to_serial_term(pid, []) ===
               "#{inspect(pid)}__term_normalizer_test_named_pid"

      Process.exit(pid, :kill)
    end

    test "unregistered local pid renders as inspect_string only" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      assert Serializer.to_serial_term(pid, []) === inspect(pid)
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

      assert Serializer.to_serial_term(pid, []) === inspect(pid)
    end
  end

  describe "to_serial_term/2 with date" do
    test "default format is extended ISO 8601" do
      assert Serializer.to_serial_term(~D[2026-05-02], []) === "2026-05-02"
    end

    test "explicit basic format respected" do
      assert Serializer.to_serial_term(~D[2026-05-02], date: [format: :basic]) === "20260502"
    end
  end

  describe "to_serial_term/2 with time" do
    test "default format is extended ISO 8601" do
      assert Serializer.to_serial_term(~T[12:34:56], []) === "12:34:56"
    end

    test "explicit basic format respected" do
      assert Serializer.to_serial_term(~T[12:34:56], time: [format: :basic]) === "123456"
    end
  end

  describe "to_serial_term/2 with datetime" do
    test "default format is extended ISO 8601" do
      assert Serializer.to_serial_term(~U[2026-05-02 12:34:56Z], []) === "2026-05-02T12:34:56Z"
    end

    test "explicit basic format respected" do
      assert Serializer.to_serial_term(~U[2026-05-02 12:34:56Z], datetime: [format: :basic]) ===
               "20260502T123456Z"
    end
  end

  describe "to_serial_term/2 with naive datetime" do
    test "default format is extended ISO 8601" do
      assert Serializer.to_serial_term(~N[2026-05-02 12:34:56], []) === "2026-05-02T12:34:56"
    end

    test "explicit basic format respected" do
      assert Serializer.to_serial_term(~N[2026-05-02 12:34:56], datetime: [format: :basic]) ===
               "20260502T123456"
    end
  end

  describe "to_serial_term/2 with generic structs" do
    test "returns a map with struct name (Elixir. stripped) and data" do
      assert Serializer.to_serial_term(%SampleStruct{a: 1, b: 2}, []) ===
               %{struct: "ExUtils.SerializerTest.SampleStruct", data: %{a: 1, b: 2}}
    end
  end

  describe "to_serial_term/2 with functions" do
    test "named-function reference returns module, function, and arity" do
      assert Serializer.to_serial_term(&String.upcase/1, []) ===
               %{module: "Elixir.String", function: "upcase", arity: 1}
    end
  end

  describe "to_serial_term/2 with primitives passes through unchanged" do
    test "binaries" do
      assert Serializer.to_serial_term("abc", []) === "abc"
    end

    test "integers" do
      assert Serializer.to_serial_term(42, []) === 42
    end

    test "floats" do
      assert Serializer.to_serial_term(1.5, []) === 1.5
    end

    test "atoms" do
      assert Serializer.to_serial_term(:foo, []) === :foo
    end

    test "booleans" do
      assert Serializer.to_serial_term(true, []) === true
      assert Serializer.to_serial_term(false, []) === false
    end

    test "nil" do
      assert Serializer.to_serial_term(nil, []) === nil
    end
  end

  describe "serialize/1 default opts" do
    test "converts an atom-keyed snake_case map to string-keyed camelCase" do
      assert Serializer.serialize(%{some_key: 1, nested: %{inner_key: 2}}) ===
               %{"someKey" => 1, "nested" => %{"innerKey" => 2}}
    end

    test "walks lists" do
      assert Serializer.serialize([%{some_key: 1}, %{some_key: 2}]) ===
               [%{"someKey" => 1}, %{"someKey" => 2}]
    end

    test "walks empty lists" do
      assert Serializer.serialize([]) === []
    end

    test "walks 2-tuples by transforming key and recursing into value" do
      assert Serializer.serialize({:some_key, %{inner_key: 1}}) ===
               {"someKey", %{"innerKey" => 1}}
    end

    test "binary keys are passed through to casing without conversion" do
      assert Serializer.serialize(%{"some_key" => 1}) === %{"someKey" => 1}
    end

    test "non-atom non-binary keys flow through serialize_key_to_string passthrough" do
      # Use a casing function that accepts any term so we can exercise the
      # passthrough clause for non-atom/non-binary keys.
      identity = fn value, _casing -> value end

      assert Serializer.serialize(%{1 => "v"}, casing_module: identity) === %{1 => "v"}
    end

    test "passes through primitives via the default JSONAble fallback" do
      assert Serializer.serialize(%{some_key: "string"}) === %{"someKey" => "string"}
      assert Serializer.serialize(%{some_key: 1.5}) === %{"someKey" => 1.5}
      assert Serializer.serialize(%{some_key: nil}) === %{"someKey" => nil}
      assert Serializer.serialize(%{some_key: true}) === %{"someKey" => true}
      assert Serializer.serialize(%{some_key: :other}) === %{"someKey" => :other}
    end
  end

  describe "serialize/2 to_case option" do
    test ":snake overrides default :camel" do
      assert Serializer.serialize(%{someKey: 1}, to_case: :snake) === %{"some_key" => 1}
    end
  end

  describe "serialize/2 invokes the default JSONAble for non-primitives" do
    test "date is dumped to ISO 8601" do
      assert Serializer.serialize(%{some_key: ~D[2026-05-02]}) === %{"someKey" => "2026-05-02"}
    end

    test "time is dumped to ISO 8601" do
      assert Serializer.serialize(%{some_key: ~T[12:34:56]}) === %{"someKey" => "12:34:56"}
    end

    test "datetime is dumped to ISO 8601" do
      dt = ~U[2026-05-02 12:34:56Z]
      assert Serializer.serialize(%{some_key: dt}) === %{"someKey" => "2026-05-02T12:34:56Z"}
    end

    test "naive datetime is dumped to ISO 8601" do
      ndt = ~N[2026-05-02 12:34:56]
      assert Serializer.serialize(%{some_key: ndt}) === %{"someKey" => "2026-05-02T12:34:56"}
    end

    test "pid is dumped to its inspect string" do
      pid = self()
      result = Serializer.serialize(%{some_key: pid})
      assert is_binary(result["someKey"])
      assert result["someKey"] =~ "#PID"
    end

    test "function is dumped to its module/function/arity map" do
      assert %{"someKey" => %{module: "Elixir.String", function: "upcase", arity: 1}} =
               Serializer.serialize(%{some_key: &String.upcase/1})
    end
  end

  describe "serialize/2 transform_value option" do
    test "1-arity function replaces dumping" do
      assert Serializer.serialize(%{some_key: 5}, transform_value: fn val -> val * 10 end) ===
               %{"someKey" => 50}
    end
  end

  describe "serialize/2 to_serial_term option" do
    test "{module, function} tuple to_serial_term is invoked" do
      assert Serializer.serialize(%{some_key: 5}, to_serial_term: {TupleDumper, :dump}) ===
               %{"someKey" => {:dumped, 5}}
    end

    test "2-arity function to_serial_term is invoked" do
      to_serial_term = fn val, _opts -> {:fun_dumper, val} end

      assert Serializer.serialize(%{some_key: 5}, to_serial_term: to_serial_term) ===
               %{"someKey" => {:fun_dumper, 5}}
    end

    test "custom module atom to_serial_term is invoked via apply/3" do
      assert Serializer.serialize(%{some_key: 5}, to_serial_term: CustomDumperModule) ===
               %{"someKey" => {:custom_dumper, 5}}
    end

    test "bogus to_serial_term raises ArgumentError" do
      assert_raise ArgumentError,
                   ~r/Expected `:to_serial_term` to be an atom, function, or/,
                   fn ->
                     Serializer.serialize(%{some_key: 5}, to_serial_term: 123)
                   end
    end
  end

  describe "deserialize/1 default opts" do
    test "round-trips a serialized map back to atom-keyed snake_case" do
      original = %{some_key: 1, nested: %{inner_key: 2}}
      serialized = Serializer.serialize(original)
      assert Serializer.deserialize(serialized) === original
    end

    test "non-binary keys are returned unchanged (atom keys)" do
      assert Serializer.deserialize(%{some_key: 1}) === %{some_key: 1}
    end

    test "non-binary keys are returned unchanged (integer keys)" do
      assert Serializer.deserialize(%{1 => "v"}) === %{1 => "v"}
    end

    test "strips surrounding quotes and whitespace from string keys" do
      assert Serializer.deserialize(%{" \"someKey\" " => 1}) === %{some_key: 1}
    end
  end

  describe "deserialize/2 strict and allowed_keys" do
    test "strict: true with explicit allowed_keys: nil and to_existing_atom: false raises" do
      assert_raise RuntimeError, ~r/allowed_keys must be provided when :strict is true/, fn ->
        Serializer.deserialize(%{"someKey" => 1},
          allowed_keys: nil,
          strict: true,
          to_existing_atom: false
        )
      end
    end

    test "strict: true with allowed_keys list permits matching keys and rejects others" do
      assert Serializer.deserialize(%{"foo" => 1},
               allowed_keys: ["foo"],
               strict: true,
               to_existing_atom: false
             ) === %{foo: 1}

      assert_raise RuntimeError, ~r/Key not allowed: bar/, fn ->
        Serializer.deserialize(%{"bar" => 1},
          allowed_keys: ["foo"],
          strict: true,
          to_existing_atom: false
        )
      end
    end

    test "strict: false with no allowed_keys creates atoms freely" do
      result =
        Serializer.deserialize(%{"freshlyCreatedKey" => 1},
          allowed_keys: nil,
          strict: false,
          to_existing_atom: false
        )

      assert Map.keys(result) === [:freshly_created_key]
      assert result[:freshly_created_key] === 1
    end

    test "allowed_keys as a MapSet works the same as a list" do
      assert Serializer.deserialize(%{"foo" => 1},
               allowed_keys: MapSet.new(["foo"]),
               strict: true,
               to_existing_atom: false
             ) === %{foo: 1}
    end

    test "allowed_keys as an invalid type and strict: true raises (treated as nil)" do
      assert_raise RuntimeError, ~r/allowed_keys must be provided when :strict is true/, fn ->
        Serializer.deserialize(%{"someKey" => 1},
          allowed_keys: 123,
          strict: true,
          to_existing_atom: false
        )
      end
    end

    test "allowed_keys as an invalid type and strict: false yields an empty allow-set" do
      assert Serializer.deserialize(%{"someKey" => 1},
               allowed_keys: 123,
               strict: false,
               to_existing_atom: false
             ) === %{:some_key => 1}
    end
  end

  describe "deserialize/2 transform_value option" do
    test "1-arity function transforms leaf values" do
      assert Serializer.deserialize(%{"someKey" => 5}, transform_value: fn v -> v * 2 end) ===
               %{some_key: 10}
    end

    test "{module, function} tuple transforms leaf values" do
      assert Serializer.deserialize(%{"someKey" => 5},
               transform_value: {TupleTransform, :call}
             ) === %{some_key: {:wrapped, 5}}
    end

    test "bogus transform_value raises ArgumentError" do
      assert_raise ArgumentError, ~r/Expected transform_value to be a 1-arity function/, fn ->
        Serializer.deserialize(%{"someKey" => 5}, transform_value: :not_a_function)
      end
    end
  end

  describe "deserialize/2 normalize_key option" do
    test "normalize_key returning an atom skips casing/atomization" do
      assert Serializer.deserialize(%{"__skip__" => 1},
               normalize_key: NormalizeKeyModule,
               allowed_keys: ["__skipped__"],
               strict: true,
               to_existing_atom: false
             ) === %{__skipped__: 1}
    end

    test "normalize_key returning a binary continues through casing" do
      assert Serializer.deserialize(%{"x_someKey" => 1},
               normalize_key: NormalizeKeyModule,
               allowed_keys: ["some_key"],
               strict: true,
               to_existing_atom: false
             ) === %{some_key: 1}
    end

    test "normalize_key returning a non-binary/non-atom raises" do
      assert_raise RuntimeError,
                   ~r/Expected normalize_key\/1 to return binary or atom/,
                   fn ->
                     Serializer.deserialize(%{"@bad@" => 1},
                       normalize_key: NormalizeKeyModule,
                       allowed_keys: ["whatever"],
                       strict: true,
                       to_existing_atom: false
                     )
                   end
    end

    test "normalize_key module not exporting normalize_key/1 raises ArgumentError" do
      assert_raise ArgumentError, ~r/to implement normalize_key\/1/, fn ->
        Serializer.deserialize(%{"someKey" => 1},
          normalize_key: NoNormalizeKey,
          allowed_keys: ["some_key"],
          strict: true,
          to_existing_atom: false
        )
      end
    end
  end
end
