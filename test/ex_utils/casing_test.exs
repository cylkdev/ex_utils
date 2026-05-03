defmodule ExUtils.CasingTest do
  use ExUnit.Case, async: true

  alias ExUtils.Casing

  defmodule UpcaseModule do
    @moduledoc false
    def to_camel(value), do: value |> to_string() |> String.upcase()
  end

  defmodule UnderscoreModule do
    @moduledoc false
    def underscore(value), do: "underscored:" <> to_string(value)
  end

  defmodule TupleCasingModule do
    @moduledoc false
    def cast(value, casing), do: "#{value}-#{casing}"
  end

  describe "to_case/3 default casing" do
    test "nil casing falls back to :snake" do
      assert Casing.to_case("someTestValue") === "some_test_value"
    end

    test "explicit nil casing falls back to :snake" do
      assert Casing.to_case("someTestValue", nil) === "some_test_value"
    end
  end

  describe "to_case/3 supported casings via default Recase" do
    test "camel" do
      assert Casing.to_case("some_test_value", :camel) === "someTestValue"
    end

    test "constant" do
      assert Casing.to_case("some_test_value", :constant) === "SOME_TEST_VALUE"
    end

    test "dot" do
      assert Casing.to_case("some_test_value", :dot) === "some.test.value"
    end

    test "header" do
      assert Casing.to_case("some_test_value", :header) === "Some-Test-Value"
    end

    test "kebab" do
      assert Casing.to_case("some_test_value", :kebab) === "some-test-value"
    end

    test "name" do
      assert Casing.to_case("some_test_value", :name) === "Some_test_value"
    end

    test "pascal" do
      assert Casing.to_case("some_test_value", :pascal) === "SomeTestValue"
    end

    test "path" do
      assert Casing.to_case("some_test_value", :path) === "some/test/value"
    end

    test "sentence" do
      assert Casing.to_case("some_test_value", :sentence) === "Some test value"
    end

    test "snake" do
      assert Casing.to_case("someTestValue", :snake) === "some_test_value"
    end

    test "title" do
      assert Casing.to_case("some_test_value", :title) === "Some Test Value"
    end

    test "underscore" do
      assert Casing.to_case("someValue", :underscore) === "some_value"
    end
  end

  describe "to_case/3 input types" do
    test "atom input is accepted by Recase and an atom is returned" do
      assert Casing.to_case(:someAtomKey, :snake) === :some_atom_key
    end
  end

  describe "to_case/3 with custom casing_module option" do
    test "casing_module as a module atom routes through to_<casing>/1" do
      assert Casing.to_case("foo", :camel, casing_module: UpcaseModule) === "FOO"
    end

    test "casing_module as a module atom routes :underscore through underscore/1" do
      assert Casing.to_case("foo", :underscore, casing_module: UnderscoreModule) ===
               "underscored:foo"
    end

    test "casing_module as {module, function} tuple invokes via apply/3 with arity 2" do
      assert Casing.to_case("foo", :kebab, casing_module: {TupleCasingModule, :cast}) ===
               "foo-kebab"
    end

    test "casing_module as a 1-arity function calls fn with the value" do
      fun = fn value -> "wrapped:" <> value end
      assert Casing.to_case("foo", :snake, casing_module: fun) === "wrapped:foo"
    end

    test "casing_module as a 2-arity function calls fn with value and casing" do
      fun = fn value, casing -> "#{value}/#{casing}" end
      assert Casing.to_case("foo", :pascal, casing_module: fun) === "foo/pascal"
    end

    test "casing_module as a function with arity > 2 raises ArgumentError" do
      fun = fn _a, _b, _c -> :unused end

      assert_raise ArgumentError, ~r/casing function must accept 1 or 2 arguments, got: 3/, fn ->
        Casing.to_case("foo", :snake, casing_module: fun)
      end
    end
  end

  describe "to_case/3 error paths" do
    test "unsupported casing atom raises ArgumentError" do
      assert_raise ArgumentError, ~r/Expected casing to be one of/, fn ->
        Casing.to_case("foo", :nonsense)
      end
    end

    test "casing module that does not export expected function raises ArgumentError" do
      defmodule NoCasingFunctions do
        @moduledoc false
        def unrelated, do: :ok
      end

      assert_raise ArgumentError, ~r/Failed to load function/, fn ->
        Casing.to_case("foo", :camel, casing_module: NoCasingFunctions)
      end
    end

    test "casing_module of an unsupported type (string) raises ArgumentError" do
      assert_raise ArgumentError,
                   ~r/Expected casing_module to be a module atom, function, or \{module, function\} tuple/,
                   fn ->
                     Casing.to_case("foo", :snake, casing_module: "not a module")
                   end
    end
  end
end
