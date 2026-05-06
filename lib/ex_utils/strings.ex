defmodule ExUtils.Strings do
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
  `config :ex_utils, ExUtils.Strings, ...`.

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
      iex> ExUtils.Strings.string_to_atom("ex_utils_string_doctest_existing", to_existing_atom: true)
      :ex_utils_string_doctest_existing

      iex> ExUtils.Strings.string_to_atom(
      ...>   "ex_utils_string_doctest_minted",
      ...>   to_existing_atom: false,
      ...>   strict: true,
      ...>   allowed_keys: ["ex_utils_string_doctest_minted"]
      ...> )
      :ex_utils_string_doctest_minted

  """

  # Abstraction Function:
  #   The module represents a stateless gate over `String.to_atom/1`
  #   and `String.to_existing_atom/1`, parameterised by an atom-safety
  #   policy (`:to_existing_atom`, `:strict`, `:allowed_keys`).
  #   `@default_atom_options` represents the static default policy.
  #   `@compiled_atom_options` represents the compile-time
  #   configuration. `@computed_atom_options` is their merge with
  #   `:allowed_keys` normalised to a `MapSet`.
  #
  # Data Invariant:
  #   1. Per-call `opts` are merged on top of `@computed_atom_options`,
  #      so caller keys always win over compile-time config.
  #   2. `:allowed_keys` is normalised to a `MapSet`: `nil` becomes
  #      `MapSet.new()`; an existing `MapSet.t()` is preserved; a
  #      `list()` is converted via `MapSet.new/1`. Any other type is
  #      treated as `nil` for runtime calls. At compile time the
  #      raise path produces `ArgumentError`.
  #   3. `:to_existing_atom === true` short-circuits to
  #      `String.to_existing_atom/1` and ignores `:strict` and
  #      `:allowed_keys`.
  #   4. With `:to_existing_atom === false` and `:strict === true`,
  #      `:allowed_keys` must be supplied; if it normalises to `nil`
  #      a `RuntimeError` is raised before the membership check.
  #   5. With `:to_existing_atom === false` and `:strict === true`,
  #      a key not in `:allowed_keys` raises
  #      `RuntimeError "Key not allowed: <key>"`.
  #   6. Otherwise, the call returns `String.to_atom(key)` with no
  #      gating.
  #   7. `key` must be `binary()` and `opts` must be a keyword list
  #      (enforced by the function head guards).
  #
  # Commutative Diagram (string_to_atom dispatch):
  #
  #             opts
  #              |
  #              | merge with @computed_atom_options
  #              v
  #          merged_opts
  #              |
  #     +--------+--------+
  #     |                 |
  #  to_existing_atom     not to_existing_atom
  #     |                 |
  #     v                 v
  #  String.to_existing_atom(key)    check strict + allowed_keys
  #                                   |
  #                                   v
  #                                String.to_atom(key)

  @app :ex_utils
  @default_atom_options [
    to_existing_atom: false,
    strict: false,
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
  Returns the atom corresponding to `key`, gated by the atom-safety
  policy.

  Three branches in priority order:

    1. `:to_existing_atom === true` -> `String.to_existing_atom(key)`.
    2. `:strict === true` -> `String.to_atom(key)` only if `key` is a
       member of `:allowed_keys`; otherwise raise.
    3. neither -> `String.to_atom(key)` unconditionally.

  Per-call `opts` are merged on top of compile-time config under
  `config :ex_utils, ExUtils.Strings, ...`, with caller keys winning.

  ## Parameters

    - `key` - `binary()`. The string to convert.
    - `opts` - `keyword()`. Recognised keys:

        * `:to_existing_atom` - `boolean()`. When `true`, only converts
          to an *existing* atom and otherwise raises.
        * `:strict` - `boolean()`. When `true` and `:to_existing_atom`
          is `false`, requires `key` to appear in `:allowed_keys`.
        * `:allowed_keys` - `MapSet.t() | list() | nil`. The set of
          keys permitted to mint new atoms when `:strict` is `true`.
          Lists are normalised to `MapSet`. `nil` is treated as the
          empty set at runtime.

  ## Returns

  `atom()`. Either an existing atom (branch 1) or a freshly minted
  atom (branches 2 and 3, when permitted). No global state is
  changed beyond the BEAM atom table on a successful mint.

  ## Raises

    - `ArgumentError` - propagated from `String.to_existing_atom/1`
      when `:to_existing_atom` is `true` and the atom does not yet
      exist.
    - `RuntimeError "allowed_keys must be provided when :strict is true"` -
      when `:to_existing_atom` is `false`, `:strict` is `true`, and
      `:allowed_keys` is `nil` or an unsupported type.
    - `RuntimeError "Key not allowed: <key>"` - when `:strict` is
      `true` and `key` is not a member of `:allowed_keys`.
    - `FunctionClauseError` - if `key` is not a binary or `opts` is
      not a list.

  ## Examples

      iex> _ = :ex_utils_string_doctest_existing
      iex> ExUtils.Strings.string_to_atom("ex_utils_string_doctest_existing", to_existing_atom: true)
      :ex_utils_string_doctest_existing

      iex> ExUtils.Strings.string_to_atom(
      ...>   "ex_utils_string_doctest_minted",
      ...>   to_existing_atom: false,
      ...>   strict: true,
      ...>   allowed_keys: ["ex_utils_string_doctest_minted"]
      ...> )
      :ex_utils_string_doctest_minted

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
