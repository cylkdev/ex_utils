defmodule ExUtils.JSON do
  @moduledoc """
  A thin JSON facade plus a coercion layer that turns Elixir terms the JSON
  encoder cannot represent (PIDs, dates, structs, function references) into
  values it can.

  The encoder and decoder delegate to Erlang/OTP's built-in `:json` module.
  Coercion is exposed as `to_jsonable_term/2` and is used by
  `ExUtils.Serializer` as the default value transformer when serializing.

  ## Responsibilities

    - Decode JSON text into Elixir terms.
    - Optionally atomize string keys on the way in via `decode/2` with
      `atomize_keys: true`. Atom creation itself is delegated to
      `ExUtils.StringUtil.string_to_atom/2`, which owns the atom-safety controls
      (`:to_existing_atom`, `:strict`, `:allowed_keys`) for the project.
    - Encode Elixir terms to JSON text, treating `nil` as the empty string
      and passing pre-encoded binaries through unchanged.
    - Convert non-JSON-able Elixir terms into JSON-friendly representations:
      ISO 8601 strings for date and time values, `%{module, function, arity}`
      maps for function references, `%{struct, data}` maps for structs, and
      annotated string forms for PIDs.
    - Pass through any term the encoder already accepts (numbers, atoms,
      booleans, binaries, `nil`).

  Coercion does *not* recurse into the `:data` field of a struct -- callers
  that need recursive normalisation should run the result back through
  `ExUtils.Serializer.serialize/2`.

  ## Atom-safety options

  `decode/2` forwards `:to_existing_atom`, `:strict`, and `:allowed_keys` to
  `ExUtils.StringUtil.string_to_atom/2`. See its module docs for semantics and
  defaults (configured under `config :ex_utils, ExUtils.StringUtil, ...`).

  Note: `decode/2` does **not** recase keys. A camelCase JSON payload with
  `atomize_keys: true` will produce camelCase atom keys. Recasing remains a
  `ExUtils.Serializer` concern.

  ## Examples

      iex> ExUtils.JSON.encode(nil)
      ""

      iex> ExUtils.JSON.encode("already encoded")
      "already encoded"

      iex> ExUtils.JSON.to_jsonable_term(~D[2026-05-02], [])
      "2026-05-02"

      iex> ExUtils.JSON.to_jsonable_term(~U[2026-05-02 12:34:56Z], [])
      "2026-05-02T12:34:56Z"

  """

  alias ExUtils.StringUtil

  @doc """
  Decodes a JSON binary into an Elixir term, returning string-keyed maps.

  Equivalent to `decode(content, [])`. Public contract preserved: callers
  relying on string keys continue to receive them.
  """
  @spec decode(binary()) :: term()
  def decode(content) when is_binary(content), do: :json.decode(content)

  @doc """
  Decodes a JSON binary into an Elixir term.

  When `:atomize_keys` is `false` (the default), behaves identically to
  `decode/1`. When `true`, walks the decoded term and converts every binary
  map key (and binary 2-tuple key) to an atom via
  `ExUtils.StringUtil.string_to_atom/2`. Lists, nested maps, and 2-tuples are
  traversed; non-binary keys, leaf values, and structs are passed through
  unchanged.

  ## Options

    * `:atomize_keys` -- `boolean()`, default `false`.
    * `:to_existing_atom`, `:strict`, `:allowed_keys` -- forwarded to
      `ExUtils.StringUtil.string_to_atom/2`. See its module docs.

  Does NOT recase keys.
  """
  @spec decode(binary(), keyword()) :: term()
  def decode(content, opts) when is_binary(content) and is_list(opts) do
    decoded = :json.decode(content)

    if Keyword.get(opts, :atomize_keys, false) do
      atomize_walk(decoded, opts)
    else
      decoded
    end
  end

  @doc """
  Encodes an Elixir term as a JSON string.

  `nil` is encoded as the empty string and pre-encoded binaries are passed
  through unchanged.
  """
  @spec encode(term()) :: binary()
  def encode(nil), do: ""
  def encode(term) when is_binary(term), do: term
  def encode(term), do: term |> :json.encode() |> IO.iodata_to_binary()

  @doc """
  Coerces a single term into a JSON-friendly representation.

  See module docs for the supported coercions.
  """
  @spec to_jsonable_term(term(), keyword()) :: term()
  def to_jsonable_term(pid, _opts) when is_pid(pid) do
    pid_string = inspect(pid)

    case Process.info(pid, :registered_name) do
      nil ->
        %{pid: pid_string, registered_name: nil}

      {:registered_name, []} ->
        %{pid: pid_string, registered_name: nil}

      {:registered_name, registered_name} ->
        %{pid: pid_string, registered_name: registered_name}
    end
  end

  def to_jsonable_term(%Date{} = date, opts) do
    Date.to_iso8601(date, opts[:date][:format] || :extended)
  end

  def to_jsonable_term(%Time{} = time, opts) do
    Time.to_iso8601(time, opts[:time][:format] || :extended)
  end

  def to_jsonable_term(%DateTime{} = date_time, opts) do
    DateTime.to_iso8601(date_time, opts[:datetime][:format] || :extended)
  end

  def to_jsonable_term(%NaiveDateTime{} = naive_date_time, opts) do
    NaiveDateTime.to_iso8601(naive_date_time, opts[:datetime][:format] || :extended)
  end

  def to_jsonable_term(%module{} = struct_data, _opts) do
    %{
      type: "struct",
      value: %{
        module: module |> Atom.to_string() |> String.replace("Elixir.", ""),
        data: Map.from_struct(struct_data)
      }
    }
  end

  def to_jsonable_term(fun, _opts) when is_function(fun) do
    {:module, module} = :erlang.fun_info(fun, :module)
    {:name, name} = :erlang.fun_info(fun, :name)
    {:arity, arity} = :erlang.fun_info(fun, :arity)

    %{
      type: "function",
      value: %{
        module: Atom.to_string(module),
        name: Atom.to_string(name),
        arity: arity
      }
    }
  end

  def to_jsonable_term(val, _opts), do: val

  # Recursive walker that atomizes binary keys at every level. Mirrors the
  # shape of Serializer's transform/3 but only touches keys -- values and
  # structs pass through unchanged. Per-key atom creation is delegated to
  # ExUtils.StringUtil.string_to_atom/2.
  defp atomize_walk(map, opts) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {key, val} ->
      {atomize_key(key, opts), atomize_walk(val, opts)}
    end)
  end

  defp atomize_walk([], _opts), do: []

  defp atomize_walk([head | tail], opts) do
    [atomize_walk(head, opts) | atomize_walk(tail, opts)]
  end

  defp atomize_walk({key, val}, opts) do
    {atomize_key(key, opts), atomize_walk(val, opts)}
  end

  defp atomize_walk(val, _opts), do: val

  defp atomize_key(key, opts) when is_binary(key), do: StringUtil.string_to_atom(key, opts)
  defp atomize_key(key, _opts), do: key
end
