defmodule ExUtils.StringUtil do
  @moduledoc """
  String utilities for `ExUtils`.

  This module owns the project's safe atom-creation primitive. Atoms are not
  garbage-collected on the BEAM, so any code path that turns external strings
  (JSON keys, query parameters, message fields) into atoms risks exhausting
  the atom table if it does not gate that creation.

  `string_to_atom/2` centralises that gate so `ExUtils.JSON` and
  `ExUtils.Serializer` share one policy:

    * Default: only convert to *existing* atoms (`:to_existing_atom`).
    * When minting new atoms is required: require an explicit allow-list
      (`:strict` + `:allowed_keys`).
    * Escape hatch: `strict: false` lets callers mint freely, at their own
      risk.

  Defaults may be set at compile time via
  `config :ex_utils, ExUtils.StringUtil, ...`.

  ## Atom-safety options

    * `:to_existing_atom` -- when `true` (the default), only converts a key
      to an existing atom and raises otherwise.
    * `:strict` -- when `true` (the default), requires that either
      `:to_existing_atom` is honoured or the key is a member of
      `:allowed_keys`.
    * `:allowed_keys` -- a `MapSet` or list of strings permitted to become
      new atoms when `:to_existing_atom` is `false`. Defaults to an empty
      set.

  ## Examples

      iex> _ = :ex_utils_string_doctest_existing
      iex> ExUtils.StringUtil.string_to_atom("ex_utils_string_doctest_existing", to_existing_atom: true)
      :ex_utils_string_doctest_existing

      iex> ExUtils.StringUtil.string_to_atom(
      ...>   "ex_utils_string_doctest_minted",
      ...>   to_existing_atom: false,
      ...>   strict: true,
      ...>   allowed_keys: ["ex_utils_string_doctest_minted"]
      ...> )
      :ex_utils_string_doctest_minted

  """

  @app :ex_utils
  @default_atom_options [
    to_existing_atom: true,
    strict: true,
    allowed_keys: nil
  ]
  @compiled_atom_options Application.compile_env(@app, __MODULE__, [])
  @computed_atom_options @default_atom_options
                         |> Keyword.merge(@compiled_atom_options)
                         |> Keyword.update!(:allowed_keys, fn
                           nil ->
                             MapSet.new()

                           %MapSet{} = set ->
                             set

                           list when is_list(list) ->
                             MapSet.new(list)

                           other ->
                             raise ArgumentError,
                                   "allowed_keys must be MapSet.t() or a list, got: #{inspect(other)}"
                         end)

  @doc """
  Safely converts a binary key to an atom according to the atom-safety
  options.

  Reads `:to_existing_atom`, `:strict`, and `:allowed_keys` from `opts`,
  falling back to compile-time defaults configured under
  `config :ex_utils, ExUtils.StringUtil, ...`.

  Raises:

    * `ArgumentError` from `String.to_existing_atom/1` when
      `:to_existing_atom` is `true` and the atom does not yet exist.
    * `RuntimeError "allowed_keys must be provided when :strict is true"`
      when `:to_existing_atom` is `false`, `:strict` is `true`, and
      `:allowed_keys` is `nil` or an unsupported type.
    * `RuntimeError "Key not allowed: <key>"` when `:strict` is `true` and
      the key is not a member of `:allowed_keys`.

  Otherwise returns `String.to_atom/1`.
  """
  @spec string_to_atom(binary(), keyword()) :: atom()
  def string_to_atom(key, opts) when is_binary(key) and is_list(opts) do
    merged = Keyword.merge(@computed_atom_options, opts)
    to_existing_atom? = merged[:to_existing_atom] === true
    strict? = merged[:strict] === true
    allowed_keys = ensure_allowed_keys!(merged[:allowed_keys], strict?)

    do_string_to_atom(key, to_existing_atom?, allowed_keys, strict?)
  end

  defp ensure_allowed_keys!(maybe_allowed_keys, strict?) do
    case normalize_allowed_keys(maybe_allowed_keys) do
      nil ->
        if strict? do
          raise "allowed_keys must be provided when :strict is true"
        else
          MapSet.new()
        end

      set ->
        set
    end
  end

  defp normalize_allowed_keys(nil), do: nil
  defp normalize_allowed_keys(%MapSet{} = set), do: set
  defp normalize_allowed_keys(list) when is_list(list), do: MapSet.new(list)
  defp normalize_allowed_keys(_), do: nil

  defp do_string_to_atom(key, true = _to_existing_atom?, _allowed_keys, _strict?) do
    String.to_existing_atom(key)
  end

  defp do_string_to_atom(key, false = _to_existing_atom?, allowed_keys, strict?) do
    allowed_key? = MapSet.member?(allowed_keys, key)

    if strict? and not allowed_key? do
      raise "Key not allowed: #{key}"
    else
      String.to_atom(key)
    end
  end
end
