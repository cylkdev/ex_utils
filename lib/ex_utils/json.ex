defmodule ExUtils.JSON do
  @moduledoc """
  A thin JSON facade over Erlang/OTP's built-in `JSON` module.

  Coercion of non-JSON-able Elixir terms (PIDs, dates, structs, function
  references) lives in `ExUtils.Serializer.to_serial_term/2`.

  ## Responsibilities

    - Decode JSON text into Elixir terms via `decode/2`.
    - Optionally atomize string keys on the way in via `decode/2` with
      `atomize_keys: true`. Atom creation itself is delegated to
      `ExUtils.Strings.string_to_atom/2`, which owns the atom-safety
      controls (`:to_existing_atom`, `:strict`, `:allowed_keys`) for
      the project.
    - Optionally route decoding through the stdlib custom-decoder
      branch (`JSON.decode/3`) when `:decoders` is supplied.
    - Encode Elixir terms to JSON text via `encode!/2`. The default
      branch delegates to `JSON.encode!/1`; the `:to_iodata` branch
      delegates to `JSON.encode_to_iodata!/2`.
    - Convert any exception raised during decoding into
      `{:error, :bad_json}`.

  ## Atom-safety options

  `decode/2` forwards `:to_existing_atom`, `:strict`, and
  `:allowed_keys` to `ExUtils.Strings.string_to_atom/2`. See its module
  docs for semantics and defaults (configured under
  `config :ex_utils, ExUtils.Strings, ...`).

  Note: `decode/2` does **not** recase keys. A camelCase JSON payload
  with `atomize_keys: true` will produce camelCase atom keys. Recasing
  remains a `ExUtils.Serializer` concern.

  See https://hexdocs.pm/elixir/JSON.html#encode!/2.

  ## Examples

      iex> ExUtils.JSON.encode!(nil)
      "null"

      iex> ExUtils.JSON.encode!(%{"a" => 1})
      ~s({"a":1})

      iex> ExUtils.JSON.decode(~s({"a":1}))
      {:ok, %{"a" => 1}}

  """

  # Abstraction Function:
  #   The module represents a stateless, two-function JSON facade:
  #     `decode/2` :: (binary, opts) -> term | {:error, :bad_json}.
  #     `encode!/2` :: (term, opts) -> binary | iodata.
  #   Internal post-processing:
  #     `maybe_atomize_keys/2` represents a recursive walker over plain
  #         maps, lists, and 2-tuples that rewrites only binary keys.
  #         Structs and 3-or-more-element tuples are opaque (returned
  #         unchanged).
  #     `apply_decode/2` represents the dispatch between
  #         `JSON.decode/1` (default) and `JSON.decode/3` (when
  #         `:decoders` is present).
  #
  # Data Invariant:
  #   1. `decode/2` requires `content` to be `binary()` and `opts` to
  #      be a keyword list (enforced by `is_binary` / `is_list` guards).
  #   2. Any exception raised during decoding (parsing or post-walk) is
  #      caught and converted to `{:error, :bad_json}`.
  #   3. `decode/2` does NOT recase keys.
  #   4. `decode/2`'s atomization step:
  #         a. recurses into plain non-struct maps (atomizing binary
  #            keys),
  #         b. recurses into lists element-wise,
  #         c. recurses into 2-tuples (atomizing only the first
  #            element when binary),
  #         d. returns any other term unchanged. As a consequence, the
  #            outer `{:ok, value}` tuple from `JSON.decode/1` is
  #            walked element-wise: `:ok` is left alone (not binary)
  #            and `value` is recursed into. The 3-tuple result of the
  #            `:decoders` branch is opaque to the walker.
  #   5. `decode/2` forwards `:to_existing_atom`, `:strict`, and
  #      `:allowed_keys` to `ExUtils.Strings.string_to_atom/2`
  #      unchanged.
  #   6. `encode!/2`'s default branch (`opts[:to_iodata]` falsy)
  #      delegates to `JSON.encode!/1` and ignores all other options.
  #   7. `encode!/2`'s `:to_iodata` branch delegates to
  #      `JSON.encode_to_iodata!/2` with `opts[:encoder]` (or
  #      `&JSON.protocol_encode/2` when absent) as the encoder.
  #
  # Commutative Diagram (decode with atomize_keys: true):
  #
  #   binary --apply_decode(opts)--> term --atomize_keys--> atomized_term
  #     |                                                       ^
  #     +-------------- decode(binary, opts) -------------------+

  alias ExUtils.Strings

  @doc """
  Returns the Elixir term decoded from `content`.

  When `:atomize_keys` is `false` (default), behaves identically to
  `JSON.decode/1` (or `JSON.decode/3` when `:decoders` is present).
  When `true`, walks the decoded term and converts every binary map
  key and the first element of every binary-keyed 2-tuple to an atom
  via `ExUtils.Strings.string_to_atom/2`. Lists, nested non-struct
  maps, and 2-tuples are traversed; non-binary keys, leaf values,
  structs, and tuples with arity other than 2 are passed through
  unchanged.

  ## Parameters

    - `content` - `binary()`. JSON text. Required to be a binary
      (enforced by `is_binary` guard).
    - `opts` - `keyword()`. Default `[]`. Recognised keys:

        * `:atomize_keys` (`boolean()`, default `false`).
        * `:decoders` (`list()`). When present, decoding routes through
          `JSON.decode/3`, returning the stdlib `{value, acc, rest}`
          3-tuple. The atomization walker treats this 3-tuple as a
          leaf and does not descend.
        * `:accumulator` (`term()`). Default `[]`. Used only when
          `:decoders` is supplied.
        * `:to_existing_atom`, `:strict`, `:allowed_keys` - forwarded
          to `ExUtils.Strings.string_to_atom/2`. See its module docs.

      Other keys are ignored.

  ## Returns

  `term() | {:error, :bad_json}`.

  On the default decode branch, returns the value `JSON.decode/1`
  produced (typically `{:ok, value}`). On the `:decoders` branch,
  returns the `{value, acc, rest}` 3-tuple from `JSON.decode/3`. With
  `atomize_keys: true`, binary map keys are converted to atoms but the
  outer tuple wrapping (`{:ok, _}` or `{value, acc, rest}`) is
  preserved. Does NOT recase keys.

  Returns `{:error, :bad_json}` when any exception is raised during
  decoding or during the atomization walk.

  ## Raises

  This function does not raise. All exceptions, including those
  produced by `JSON.decode!/1`, atomize-key forwarders, or
  `:decoders`, are caught and reported as `{:error, :bad_json}`.

  Note: `FunctionClauseError` will be raised at the entry guards if
  `content` is not a binary or `opts` is not a list.

  ## Examples

      iex> ExUtils.JSON.decode(~s({"a":1,"b":"two"}))
      {:ok, %{"a" => 1, "b" => "two"}}

      iex> ExUtils.JSON.decode("not json")
      {:error, :bad_json}

  """
  @spec decode(binary(), keyword()) :: term() | {:error, :bad_json}
  def decode(content, opts \\ []) when is_binary(content) and is_list(opts) do
    content
    |> apply_decode(opts)
    |> maybe_atomize_keys(opts)
  rescue
    _ -> {:error, :bad_json}
  end

  defp apply_decode(content, opts) do
    if Keyword.has_key?(opts, :decoders) do
      JSON.decode(content, opts[:accumulator] || [], opts[:decoders])
    else
      JSON.decode(content)
    end
  end

  @doc """
  Returns `term` encoded as JSON.

  Default branch (`opts[:to_iodata]` is absent or falsy) delegates to
  `JSON.encode!/1` and returns a `binary()`. The `:to_iodata` branch
  delegates to `JSON.encode_to_iodata!/2` and returns iodata.

  ## Parameters

    - `term` - `term()`. Any term `JSON.encode!/1` accepts. Non-JSON
      terms (PIDs, dates, structs, function references) are not
      coerced here; use `ExUtils.Serializer.serialize/2` first.
    - `opts` - `keyword()`. Default `[]`. Recognised keys:

        * `:to_iodata` (`boolean()`). When `true`, returns iodata via
          `JSON.encode_to_iodata!/2`. Otherwise the default branch is
          taken.
        * `:encoder` (function). Used only on the `:to_iodata` branch.
          Defaults to `&JSON.protocol_encode/2`.

      All other keys are ignored on both branches.

  ## Returns

  `binary() | iodata()`. The default branch returns a `binary()`
  produced by `JSON.encode!/1`. The `:to_iodata` branch returns the
  iodata produced by `JSON.encode_to_iodata!/2`. `nil` encodes to
  `"null"` (delegated unchanged from `JSON.encode!/1`); pre-encoded
  binaries are JSON-string-quoted.

  ## Raises

    - Any exception `JSON.encode!/1` or `JSON.encode_to_iodata!/2`
      raises is propagated unchanged (commonly `Protocol.UndefinedError`
      for non-encodable terms).

  ## Examples

      iex> ExUtils.JSON.encode!(%{"a" => 1})
      ~s({"a":1})

      iex> ExUtils.JSON.encode!(nil)
      "null"

      iex> ExUtils.JSON.encode!(%{"a" => 1}, to_iodata: true) |> IO.iodata_to_binary()
      ~s({"a":1})

  """
  @spec encode!(term(), keyword()) :: binary() | iodata()
  def encode!(term, opts \\ []) do
    case opts[:to_iodata] do
      true -> JSON.encode_to_iodata!(term, opts[:encoder] || (&JSON.protocol_encode/2))
      _ -> JSON.encode!(term)
    end
  end

  defp maybe_atomize_keys(payload, opts) do
    if Keyword.get(opts, :atomize_keys, false) do
      atomize_keys(payload, opts)
    else
      payload
    end
  end

  # Recursive walker that atomizes binary keys at every level. Mirrors the
  # shape of Serializer's transform/3 but only touches keys -- values and
  # structs pass through unchanged. Per-key atom creation is delegated to
  # ExUtils.Strings.string_to_atom/2.
  defp atomize_keys(map, opts) when is_map(map) and not is_struct(map) do
    Map.new(map, fn {key, val} ->
      {atomize_key(key, opts), atomize_keys(val, opts)}
    end)
  end

  defp atomize_keys([], _opts), do: []

  defp atomize_keys([head | tail], opts) do
    [atomize_keys(head, opts) | atomize_keys(tail, opts)]
  end

  defp atomize_keys({key, val}, opts) do
    {atomize_key(key, opts), atomize_keys(val, opts)}
  end

  defp atomize_keys(val, _opts), do: val

  defp atomize_key(key, opts) when is_binary(key), do: Strings.string_to_atom(key, opts)
  defp atomize_key(key, _opts), do: key
end
