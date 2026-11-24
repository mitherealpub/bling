defmodule BlingTest.Plan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "plans" do
    field :stripe_price_id, :string
    field :stripe_product_id, :string
    field :name, :string
    field :description, :string
    field :unit_amount, :integer
    field :currency, :string
    field :interval, :string
    field :usage_type, :string, default: "licensed"
    field :meter_event_name, :string
    field :active, :boolean, default: true
    field :metadata, :map, default: %{}

    timestamps()
  end

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [
      :stripe_price_id, :stripe_product_id, :name, :description,
      :unit_amount, :currency, :interval, :usage_type,
      :meter_event_name, :active, :metadata
    ])
    |> validate_required([:stripe_price_id, :stripe_product_id, :name])
    |> unique_constraint(:stripe_price_id)
  end
end
