defmodule ExUtils.Casing do
  @moduledoc """
  A configurable adapter for converting strings between casing styles.

  Wraps an underlying casing library (default: [`Recase`](https://hexdocs.pm/recase))
  behind a single `to_case/3` entrypoint. Callers pick the casing by atom and
  the adapter routes the call to the right function on the configured backend,
  validating that the function actually exists before invoking it.

  The backend is pluggable: it may be a module atom, a `{module, function}`
  tuple, or an inline 1- or 2-arity function. This lets a project swap in a
  custom casing implementation without changing call sites.

  ## Responsibilities

    - Convert a value to one of the supported casings: `:camel`, `:constant`,
      `:dot`, `:header`, `:kebab`, `:name`, `:pascal`, `:path`, `:sentence`,
      `:snake` (default), `:title`, `:underscore`.
    - Resolve the backend from `opts[:casing_module]`, falling back to
      `Recase`.
    - Raise `ArgumentError` when the requested casing is unsupported, the
      backend does not export the required function, or the backend value is
      not a recognised shape.

  ## Examples

      iex> ExUtils.Casing.to_case("HelloWorld")
      "hello_world"

      iex> ExUtils.Casing.to_case("hello_world", :camel)
      "helloWorld"

      iex> ExUtils.Casing.to_case("HelloWorld", :kebab)
      "hello-world"

  """

  @default_casing_module Recase
  @default_casing :snake
  @supported_casings [
    :camel,
    :constant,
    :dot,
    :header,
    :kebab,
    :name,
    :pascal,
    :path,
    :sentence,
    :snake,
    :title,
    :underscore
  ]

  def to_case(term, casing \\ nil, opts \\ []) do
    casing_module = casing_module!(opts)
    apply_casing!(term, casing || @default_casing, casing_module)
  end

  defp apply_casing!(value, casing, {mod, fun})
       when is_atom(mod) and not is_nil(mod) and (is_atom(fun) and not is_nil(fun)) do
    ensure_function_exported!(mod, fun, 2)
    apply(mod, fun, [value, casing])
  end

  defp apply_casing!(value, casing, fun) when is_function(fun) do
    case :erlang.fun_info(fun, :arity) do
      {:arity, 2} ->
        fun.(value, casing)

      {:arity, 1} ->
        fun.(value)

      {:arity, n} ->
        raise ArgumentError, "casing function must accept 1 or 2 arguments, got: #{n}"
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp apply_casing!(value, casing, casing_module)
       when is_atom(casing_module) and not is_nil(casing_module) do
    case casing do
      :camel ->
        ensure_function_exported!(casing_module, :to_camel, 1)
        casing_module.to_camel(value)

      :constant ->
        ensure_function_exported!(casing_module, :to_constant, 1)
        casing_module.to_constant(value)

      :dot ->
        ensure_function_exported!(casing_module, :to_dot, 1)
        casing_module.to_dot(value)

      :header ->
        ensure_function_exported!(casing_module, :to_header, 1)
        casing_module.to_header(value)

      :kebab ->
        ensure_function_exported!(casing_module, :to_kebab, 1)
        casing_module.to_kebab(value)

      :name ->
        ensure_function_exported!(casing_module, :to_name, 1)
        casing_module.to_name(value)

      :pascal ->
        ensure_function_exported!(casing_module, :to_pascal, 1)
        casing_module.to_pascal(value)

      :path ->
        ensure_function_exported!(casing_module, :to_path, 1)
        casing_module.to_path(value)

      :sentence ->
        ensure_function_exported!(casing_module, :to_sentence, 1)
        casing_module.to_sentence(value)

      :snake ->
        ensure_function_exported!(casing_module, :to_snake, 1)
        casing_module.to_snake(value)

      :title ->
        ensure_function_exported!(casing_module, :to_title, 1)
        casing_module.to_title(value)

      :underscore ->
        ensure_function_exported!(casing_module, :underscore, 1)
        casing_module.underscore(value)

      term ->
        raise ArgumentError,
              "Expected casing to be one of #{Enum.join(@supported_casings, ", ")}, got: #{inspect(term)}"
    end
  end

  defp apply_casing!(_value, _casing, casing_module) do
    raise ArgumentError,
          "Expected casing_module to be a module atom, function, or {module, function} tuple, got: #{inspect(casing_module)}"
  end

  defp ensure_function_exported!(mod, fun, arity) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, fun, arity) do
      :ok
    else
      raise ArgumentError, "Failed to load function #{mod}.#{fun}/#{arity}"
    end
  end

  # Returns `opts[:casing_module]` if provided; otherwise returns the default
  # `@default_casing_module`. Performs no assertions on the returned value.
  defp casing_module!(opts) do
    opts[:casing_module] || @default_casing_module
  end
end
