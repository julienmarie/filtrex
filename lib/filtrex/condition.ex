defmodule Filtrex.Condition do
  @moduledoc """
  `Filtrex.Condition` is an abstract module for parsing conditions.
  To implement your own condition, add `@behaviour Filtrex.Condition` in your module and implement the three callbacks:

    * `parse/2` - produce a condition struct from a configuration and attributes
    * `type/0` - the description of the condition that must match the underscore version of the module's last namespace
    * `comparators/0` - the list of used query comparators for parsing params
  """

  @callback parse(Map.t, %{inverse: boolean, column: String.t, value: any, comparator: String.t}) :: {:ok, any} | {:error, any}
  @callback type :: Atom.t
  @callback comparators :: [String.t]

  defstruct column: nil, comparator: nil, value: nil

  @doc """
  Parses a condition by dynamically delegating to modules

  It delegates based on the type field of the options map (e.g. `Filtrex.Condition.Text` for the type `"text"`).
  Example Input:
  config:
  ```
  Filtrex.Condition.parse(%{
    text: %{keys: ~w(title comments)}  # passed to the specific condition
  }, %{
    type: string,                      # converted to Filtrex.Condition."__" dynamically
    column: string,
    comparator: string,
    value: string,
    inverse: boolean                   # inverts the comparator logic
  })
  ```
  """
  def parse(config, options = %{type: type}) do
    case condition_module(type) do
      nil ->
        {:error, ["Unknown filter condition '#{type}'"]}
      module ->
        type_atom = String.to_existing_atom(type)
        module.parse(config[type_atom], Map.delete(options, :type))
    end
  end

  @doc "Parses a params key into the condition type, column, and comparator"
  def param_key_type(config, key_with_comparator) do
    result = Enum.find_value(condition_modules, fn (module) ->
      Enum.find_value(module.comparators, fn (comparator) ->
        normalized = "_" <> String.replace(comparator, " ", "_")
        key = String.replace_trailing(key_with_comparator, normalized, "")
        %{keys: allowed_keys} = config[module.type]
        if key in allowed_keys, do: {:ok, module, key, comparator}
      end)
    end)
    if result, do: result, else: {:error, "Unknown filter key"}
  end

  defmacro encoder(type, comparator, reverse_comparator, expression, values_function \\ {:&, [], [[{:&, [], [1]}]]}) do
    quote do
      def encode(condition = %{comparator: unquote(comparator), inverse: true}) do
        condition |> struct(inverse: false, comparator: unquote(reverse_comparator)) |> encode
      end

      def encode(%{column: column, comparator: unquote(comparator), value: value}) do
        %Filtrex.Fragment{
          expression: String.replace(unquote(expression), "column", column),
          values: unquote(values_function).(value)
        }
      end
    end
  end

  @doc "Helper method to validate whether a value is in a list"
  @spec validate_in(any, List.t) :: nil | any
  def validate_in(nil, _), do: nil
  def validate_in(_, nil), do: nil
  def validate_in(value, list) do
    cond do
      value in list -> value
      true -> nil
    end
  end

  @doc "Helper method to validate whether a value is a binary"
  @spec validate_is_binary(any) :: nil | String.t
  def validate_is_binary(value) when is_binary(value), do: value
  def validate_is_binary(_), do: nil

  @doc "Generates an error description for a generic parse error"
  @spec parse_error(any, Atom.t, Atom.t) :: String.t
  def parse_error(value, type, filter_type) do
    "Invalid #{to_string(filter_type)} #{to_string(type)} '#{value}'"
  end

  @doc "Generates an error description for a parse error resulting from an invalid value type"
  @spec parse_value_type_error(any, Atom.t) :: String.t
  def parse_value_type_error(column, filter_type) when is_binary(column) do
    "Invalid #{to_string(filter_type)} value for #{column}"
  end

  def parse_value_type_error(column, filter_type) do
    opts   = struct(Inspect.Opts, [])
    iodata = Inspect.Algebra.to_doc(column, opts)
      |> Inspect.Algebra.format(opts.width)
      |> Enum.join

    cond do
      String.length(iodata) <= 15 ->
        parse_value_type_error("'#{iodata}'", filter_type)
      true ->
        "'#{String.slice(iodata, 0..12)}...#{String.slice(iodata, -3..-1)}'"
          |> parse_value_type_error(filter_type)
    end
  end

  defp condition_modules do
    modules = [
      Filtrex.Condition.Text,
      Filtrex.Condition.Date
    ]
    Application.get_env(:filtrex, :conditions, modules)
  end

  defp condition_module(type) do
    Enum.find(condition_modules, fn (module) ->
      condition_type = to_string(module)
        |> String.split(".")
        |> List.last
        |> Mix.Utils.underscore
      type == condition_type
    end)
  end
end

defprotocol Filtrex.Encoder do
  @moduledoc """
  Encodes a condition into `Filtrex.Fragment` as an expression with values

  Example:
  ```
  defimpl Filtrex.Encoder, for: Filtrex.Condition.Text do
    def encode(%Filtrex.Condition.Text{column: column, comparator: "is", value: value}) do
      %Filtrex.Fragment{expression: "\#\{column\} = ?", values: [value]}
    end
  end
  ```
  """

  @spec encode(Filter.Condition.t) :: [String.t | [any]]
  def encode(condition)
end
