defmodule ParamsTest do
  use ExUnit.Case

  @config %{text: %{keys: ["title"]}, date: %{keys: ["date_column"]}}

  test "parsing valid text parameters" do
    params = %{"title_contains" => "blah"}
    assert Filtrex.Params.parse_conditions(@config, params) ==
      {:ok, [%Filtrex.Condition.Text{
        type: :text,
        inverse: false,
        column: "title",
        value: "blah",
        comparator: "contains"
      }]}
  end

  test "parsing valid date parameters" do
    params = %{"date_column_between" => %{"start" => "2016-03-10", "end" => "2016-03-20"}}
    assert Filtrex.Params.parse_conditions(@config, params) ==
      {:ok, [%Filtrex.Condition.Date{
        type: :date,
        inverse: false,
        column: "date_column",
        value: %{start: "2016-03-10", end: "2016-03-20"},
        comparator: "between"
      }]}
  end

  test "bubbling up errors from value parsing" do
    params = %{"date_column_between" => %{"start" => "2016-03-10"}}
    assert Filtrex.Params.parse_conditions(@config, params) ==
      {:error, "Invalid date value format: Both a start and end key are required."}
  end

  test "returning error if unknown keys" do
    params = %{"title_contains" => "blah", "extra_key" => "true"}
    assert Filtrex.Params.parse_conditions(@config, params) ==
      {:error, "Unknown filter key"}
  end
end
