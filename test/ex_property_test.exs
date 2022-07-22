defmodule ExPropertyTest do
  use ExUnit.Case

  defmodule Example do
    use ExProperty

    # Each property receives a value of `input` type.
    @type input :: integer()

    # Each property must have a type.
    # Dialyzer should report errors properly.
    @property p :: integer()
    property p(i, _) do
      i + 1
    end

    @property q :: integer()

    # A property is a binary function that receives the input
    # and a subset of properties (the Example struct is defined
    #  automatically, containing all the defined properties).
    property q(i, %Example{p: p}) when p > 0, do: i * 5
    property q(i, %Example{p: 3}), do: i * 5
    property q(i, %Example{p: p}), do: p * i

    # Cycles are not allowed and are identified at compile-time.
    # Enabling the following line will cause a `LoopError`:
    #   property q(i, %Example{z: z}), do: z / i

    @property r :: integer()
    property r(_, %Example{p: p, q: q, z: _z}) do
      p * q
    end

    @property z :: integer()
    property z(_, %__MODULE__{q: q}) do
      q * 5
    end
  end

  test "deriving all the properties from the input" do
    assert %Example{p: 3, q: 10, r: 30, z: 50} == Example.new(2)
  end
end
