defmodule BlingTest.Repo.Migrations.CreatePlans do
  use Ecto.Migration

  def change do
    create table(:plans) do
      add :stripe_price_id, :string, null: false
      add :stripe_product_id, :string, null: false
      add :name, :string, null: false
      add :description, :string
      add :unit_amount, :integer
      add :currency, :string, default: "usd"
      add :interval, :string
      add :usage_type, :string, default: "licensed"
      add :meter_event_name, :string
      add :active, :boolean, default: true
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:plans, [:stripe_price_id])
  end
end
