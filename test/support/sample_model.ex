defmodule Filtrex.SampleModel do
  use Ecto.Schema

  schema "sample_models" do
    field :title
    field :date_column, Ecto.Date
    field :time_column, Ecto.Time
    field :comments
    
    timestamps
  end
end