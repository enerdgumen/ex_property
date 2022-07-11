defmodule Property do
  @moduledoc """
  Documentation for `Property`.
  """

  defmodule LoopError do
    defexception [:message]

    @impl true
    def exception(value) do
      %LoopError{message: "loop found at #{inspect(value)}"}
    end
  end

  defmodule Overrides do
    @moduledoc false

    import Kernel, except: [@: 1]

    defmacro @{:property, _, [expr]} do
      quote location: :keep do
        @type unquote(expr)
      end
    end

    defmacro @ast do
      quote location: :keep do
        Kernel.@(unquote(ast))
      end
    end
  end

  defmacro __using__(_) do
    quote do
      import Kernel, except: [@: 1]
      import Overrides, only: [@: 1]
      import Property
      alias __MODULE__
      Module.register_attribute(__MODULE__, :property, accumulate: true)
      Module.register_attribute(__MODULE__, :definition, accumulate: true)
      @before_compile Property
    end
  end

  defmacro property(call, body) do
    property = name_and_required_properties(call)

    quote do
      @property unquote(property)
      @definition unquote(Macro.escape({call, body}))
    end
  end

  @spec name_and_required_properties(Macro.t()) :: {atom, [atom]}
  defp name_and_required_properties(ast) do
    case ast do
      {:when, _, [call, _guard]} -> name_and_required_properties(call)
      {name, _, [_input, props]} -> {name, required_properties(props)}
    end
  end

  @spec required_properties(Macro.t()) :: [atom]
  defp required_properties(ast) do
    case ast do
      {:%{}, _, props} -> Keyword.keys(props)
      {:%, _, [_alias, map]} -> required_properties(map)
      {:=, _, args} -> Enum.flat_map(args, &required_properties/1)
      {:_, _, _} -> []
    end
  end

  defmacro __before_compile__(%{module: module}) do
    properties = Module.delete_attribute(module, :property)
    building_order = building_order(properties)
    names = properties |> Keyword.keys() |> Enum.uniq()
    definitions = module |> Module.delete_attribute(:definition) |> Enum.reverse()

    quote do
      @spec new(input()) :: t()
      def new(input) do
        Property.build(__MODULE__, unquote(building_order), input)
      end

      unquote(generate_type(names))
      unquote(generate_struct(names))
      unquote(generate_specs(names))
      unquote(generate_defs(definitions))
    end
  end

  # @type t :: %__MODULE__{
  #         p: p(),
  #         q: q(),
  #         r: r()
  #       }
  @spec generate_type([atom]) :: Macro.t()
  defp generate_type(names) do
    fields = Enum.map(names, &{_name = &1, {_type = &1, [], []}})
    map = {:%{}, [], fields}
    struct = {:%, [], [{:__MODULE__, [if_undefined: :apply], Elixir}, map]}

    quote do
      @type t :: unquote(struct)
    end
  end

  @spec generate_struct([atom]) :: Macro.t()
  defp generate_struct(names) do
    quote do
      defstruct unquote(names)
    end
  end

  @spec generate_specs([atom]) :: Macro.t()
  defp generate_specs(names) do
    specs =
      for name <- names do
        quote do
          @spec unquote(name)(input(), t()) :: unquote(name)()
        end
      end

    quote do
      (unquote_splicing(specs))
    end
  end

  @spec generate_defs([{Macro.t(), Macro.t()}]) :: Macro.t()
  defp generate_defs(definitions) do
    defs =
      for {call, body} <- definitions do
        quote do
          def unquote(call), unquote(body)
        end
      end

    quote do
      (unquote_splicing(defs))
    end
  end

  @spec building_order([{atom, [atom]}]) :: [atom]
  defp building_order(properties) do
    graph =
      for {property, depends_on} <- properties,
          other_property <- depends_on,
          reduce: Graph.new() do
        g -> Graph.add_edge(g, other_property, property)
      end

    if Graph.is_cyclic?(graph) do
      raise LoopError, Graph.loop_vertices(graph)
    end

    Graph.topsort(graph)
  end

  @spec build(module(), [atom()], any) :: struct()
  def build(module, properties, input) do
    for name <- properties, reduce: struct(module) do
      it ->
        value = apply(module, name, [input, it])
        Map.put(it, name, value)
    end
  end
end
