defmodule ExUtils.Compressor.Adapter do
  @moduledoc """
  The behaviour every compressor adapter must implement.

  A conforming module is a stateless `compress/2` and `decompress/2` pair
  that satisfies a round-trip contract: feeding `compress/2`'s output back
  through `decompress/2` with compatible `opts` recovers the original
  binary. `ExUtils.Compressor` routes calls to a module that conforms to this
  behaviour.

  ## Responsibilities

    - Define the signatures of `compress/2` and `decompress/2` that every
      adapter must export.
    - Fix the shape of arguments callers and the router may forward
      (`binary()` content, `keyword()` options).
    - Establish the round-trip contract adapter implementations must
      preserve.

  ## Examples

      defmodule MyApp.NoOpAdapter do
        @behaviour ExUtils.Compressor.Adapter

        @impl true
        def compress(content, _opts), do: content

        @impl true
        def decompress(compressed, _opts), do: compressed
      end

  """

  # Abstraction Function:
  #   A module conforming to this behaviour represents an invertible
  #   binary-to-binary encoding parameterised by `opts`. `compress/2` is the
  #   forward map; `decompress/2` is its inverse.
  #   The behaviour itself has no state -- it is a contract over function
  #   shapes, not an ADT.
  #
  # Data Invariant:
  #   1. Both callbacks accept `binary()` content and a keyword-list `opts`.
  #   2. Both callbacks return `binary()`.
  #   3. For every `content :: binary()` and every `opts` that select the
  #      same codec on both sides, `decompress(compress(content, opts), opts)`
  #      equals `content`.
  #
  # Commutative Diagram (round-trip):
  #
  #   content  --compress(opts)-->  compressed
  #      ^                              |
  #      |                              |
  #      +-------decompress(opts)-------+

  @callback compress(content :: binary(), opts :: keyword()) :: binary()
  @callback decompress(compressed :: binary(), opts :: keyword()) :: binary()
end
