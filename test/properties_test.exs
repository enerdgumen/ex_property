defmodule PropertiesTest do
  use ExUnit.Case

  defmodule Example do
    use Property

    @type input :: integer()

    @property p :: integer()
    property p(i, _) do
      i + 1
    end

    @property q :: integer()
    property q(i, %Example{p: 3}), do: i * 5
    property q(i, %Example{p: p}) when p > 0, do: i * 5
    property q(i, %Example{p: p}), do: p * i

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
