defmodule BlingTest.Plan do
  use Ecto.Schema
  import Ecto.Changeset

   field :stripe_price_id, :string
    field :stripe_product_id, :string
    field :name, :string
    field :description, :string
    field :unit_amount, :integer
    field :unit_amount_decimal, :string
    field :currency, :string
    field :interval, :string
    field :billing_scheme, :string, default: "per_unit"
    field :usage_type, :string, default: "licensed"
    field :meter_event_name, :string
    field :tiers, {:array, :map}, default: []
    field :active, :boolean, default: true
    field :metadata, :map, default: %{}

    timestamps()
  end

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [
      :stripe_price_id, :stripe_product_id, :name, :description,
      :unit_amount, :unit_amount_decimal, :currency, :interval,
      :billing_scheme, :usage_type, :meter_event_name, :tiers,
      :active, :metadata
    ])
    |> validate_required([:stripe_price_id, :stripe_product_id, :name])
    |> unique_constraint(:stripe_price_id)
  end
end
