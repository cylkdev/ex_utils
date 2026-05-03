defmodule ExUtils.Serializer do
  @moduledoc """
  Recursively transforms Elixir data structures between an internal "Elixir"
  shape and an external "wire" shape.

  `serialize/2` rewrites map and keyword keys into a string casing suitable for
  transport (default `:camel`) and coerces leaf values into JSON-friendly
  terms via `ExUtils.JSON.to_jsonable_term/2` (or a caller-supplied
  transformer).

  `deserialize/2` is the inverse for keys: it trims and unquotes incoming
  string keys, optionally normalises them through a caller-supplied
  `normalize_key/1` module, recases them (default `:snake`), and converts them
  to atoms. The atomization step delegates to
  `ExUtils.StringUtil.string_to_atom/2`, which owns the atom-safety controls
  (`:to_existing_atom`, `:strict`, `:allowed_keys`) for the project.
  Leaf values are passed through the optional `:transform_value` function
  unchanged otherwise.

  Traversal walks plain maps (not structs), lists, and 2-tuples (so keyword
  lists are handled). Structs and other terms are treated as leaves.

  ## Responsibilities

    - Rewrite map/keyword keys to a target casing on the way out (`serialize`)
      and back to atoms on the way in (`deserialize`).
    - Coerce non-JSON-able leaf values during serialization via a configurable
      transformer (defaults to `ExUtils.JSON.to_jsonable_term/2`).
    - Apply caller-supplied value transforms during deserialization.
    - Forward atom-safety options to `ExUtils.StringUtil.string_to_atom/2`,
      which raises rather than silently creating atoms when the configuration
      disallows them.
    - Read defaults for normalize/transform options from compile-time
      configuration under `config :ex_utils, ExUtils.Serializer, ...`, with
      per-call `opts` overriding them. Atom-safety defaults live in
      `ExUtils.StringUtil` (see its module docs).

  ## Options

    * `:to_case` -- target casing for keys. Defaults to `:camel` for
      `serialize/2` and `:snake` for `deserialize/2`. See `ExUtils.Casing` for
      the full list.
    * `:to_existing_atom`, `:strict`, `:allowed_keys` -- forwarded as-is to
      `ExUtils.StringUtil.string_to_atom/2`. See its docs for semantics and
      defaults.
    * `:normalize_key` -- a module exporting `normalize_key/1`, applied to
      each string key before recasing during deserialization.
    * `:transform_value` -- a 1-arity function or `{module, function}` tuple
      applied to each leaf value. On `serialize/2` it overrides the JSON
      coercion; on `deserialize/2` it transforms incoming leaves.
    * `:to_jsonable_term` -- the value coercion strategy used by `serialize/2`
      when `:transform_value` is not set. Accepts a module, a 2-arity
      function, or a `{module, function}` tuple. Defaults to `ExUtils.JSON`.

  ## Examples

      # Serialize a struct-free map to camelCase string keys
      ExUtils.Serializer.serialize(%{user_name: "ada", joined_at: ~D[2026-05-02]})
      #=> %{"userName" => "ada", "joinedAt" => "2026-05-02"}

      # Deserialize incoming camelCase JSON to existing snake_case atom keys
      ExUtils.Serializer.deserialize(
        %{"userName" => "ada"},
        allowed_keys: [\"user_name\"],
        to_existing_atom: false
      )
      #=> %{user_name: "ada"}

  """

  alias ExUtils.Casing
  alias ExUtils.JSON
  alias ExUtils.StringUtil

  @app :ex_utils
  @json_module JSON
  @default_options [
    normalize_key: nil,
    transform_value: nil
  ]
  @compiled_options Application.compile_env(@app, __MODULE__, [])
  @computed_options Keyword.merge(@default_options, @compiled_options)

  @doc """
  Serializes an Elixir term into a JSON-friendly shape with recased keys.

  See module docs for behavior and options.
  """
  @spec serialize(term(), keyword()) :: term()
  def serialize(term, opts \\ []) do
    opts = Keyword.merge(@computed_options, opts)
    val_fun = opts[:transform_value]

    transform(
      term,
      fn key ->
        key
        |> serialize_key_to_string()
        |> Casing.to_case(opts[:to_case] || :camel, opts)
      end,
      fn val ->
        if is_nil(val_fun) do
          dump_term!(val, opts)
        else
          val_fun.(val)
        end
      end
    )
  end

  defp serialize_key_to_string(key) when is_atom(key), do: Atom.to_string(key)
  defp serialize_key_to_string(key) when is_binary(key), do: key
  defp serialize_key_to_string(key), do: key

  defp dump_term!(val, opts) do
    case opts[:to_jsonable_term] || @json_module do
      JSON ->
        JSON.to_jsonable_term(val, opts)

      mod when is_atom(mod) and not is_nil(mod) ->
        mod.to_jsonable_term(val, opts)

      fun when is_function(fun, 2) ->
        fun.(val, opts)

      {mod, fun} ->
        apply(mod, fun, [val, opts])

      term ->
        raise ArgumentError,
              "Expected `:to_jsonable_term` to be an atom, function, or {module, function}, got: #{inspect(term)}"
    end
  end

  @doc """
  Deserializes an external term into an Elixir-shaped term with atom keys.

  Forwards atom-safety options to `ExUtils.StringUtil.string_to_atom/2`. See
  module docs for behavior and options.
  """
  @spec deserialize(term(), keyword()) :: term()
  def deserialize(term, opts \\ []) do
    opts = Keyword.merge(@computed_options, opts)
    val_fun = opts[:transform_value]
    transform(term, fn key -> deserialize_key(key, opts) end, val_fun)
  end

  # Transforms a single key. Binary keys are trimmed, stripped of `"`, optionally
  # normalized, snake-cased, and atomized via ExUtils.StringUtil.string_to_atom/2.
  # Non-binary keys are returned unchanged.
  defp deserialize_key(key, opts) when is_binary(key) do
    case key |> trim_and_strip_quotes() |> normalize_key(opts) do
      string_key when is_binary(string_key) ->
        normalized_key = Casing.to_case(string_key, opts[:to_case] || :snake, opts)
        StringUtil.string_to_atom(normalized_key, opts)

      skipped_key when is_atom(skipped_key) ->
        skipped_key
    end
  end

  defp deserialize_key(key, _opts), do: key

  defp trim_and_strip_quotes(key) do
    key |> String.trim() |> String.replace("\"", "")
  end

  # Recursive worker. Walks non-struct maps, lists, and 2-tuples; applies `key_fun` to
  # keys and `val_fun` to leaf values reached at the bottom of the traversal.
  defp transform(map, key_fun, val_fun) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {key, val} ->
      {key_fun.(key), transform(val, key_fun, val_fun)}
    end)
  end

  defp transform([], _key_fun, _val_fun) do
    []
  end

  defp transform([head | tail], key_fun, val_fun) do
    [transform(head, key_fun, val_fun) | transform(tail, key_fun, val_fun)]
  end

  defp transform({key, val}, key_fun, val_fun) do
    {key_fun.(key), transform(val, key_fun, val_fun)}
  end

  defp transform(val, _key_fun, val_fun) do
    apply_transform(val, val_fun)
  end

  # Applies a value transform: `nil` is a no-op, a 1-arity function is invoked,
  # an `{atom, atom}` tuple is invoked via `apply/3`.
  defp apply_transform(val, nil), do: val

  defp apply_transform(val, fun) when is_function(fun, 1) do
    fun.(val)
  end

  defp apply_transform(val, {mod, fun})
       when is_atom(mod) and not is_nil(mod) and (is_atom(fun) and not is_nil(fun)) do
    apply(mod, fun, [val])
  end

  defp apply_transform(_val, term) do
    raise ArgumentError,
          "Expected transform_value to be a 1-arity function or {module, function}, got: #{inspect(term)}"
  end

  # Applies `opts[:normalize_key].normalize_key/1` when configured; otherwise returns
  # `val` unchanged. Raises if the result is neither binary nor atom.
  defp normalize_key(val, opts) do
    case opts[:normalize_key] do
      nil ->
        val

      mod ->
        ensure_normalize_key_exported!(mod)

        case mod.normalize_key(val) do
          val when is_binary(val) -> val
          val when is_atom(val) -> val
          _ -> raise "Expected normalize_key/1 to return binary or atom, got: #{inspect(val)}"
        end
    end
  end

  # Raises `ArgumentError` if `mod` does not export `normalize_key/1`. Forces module
  # load first so the check works for modules that have not yet been referenced at runtime.
  defp ensure_normalize_key_exported!(mod) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, :normalize_key, 1) do
      :ok
    else
      raise ArgumentError, "Expected module #{mod} to implement normalize_key/1"
    end
  end
end
