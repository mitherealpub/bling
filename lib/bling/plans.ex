defmodule Bling.Plans do
  import Ecto.Query

  def list_active do
    plan_schema = Bling.plan()
    Bling.repo().all(from p in plan_schema, where: p.active == true, order_by: [asc: p.unit_amount])
  end

  def sync_all(stripe_opts \\ %{}) do
    params =
      Map.merge(
        %{active: true, expand: ["data.product", "data.tiers"], limit: 100},
        stripe_opts
      )

    with {:ok, %{data: prices}} <- Stripe.Price.list(params) do
      Enum.each(prices, &upsert_from_stripe/1)
      :ok
    end
  end

  def upsert_from_stripe(%Stripe.Price{} = price) do
    plan_schema = Bling.plan()

    product =
      case price.product do
        %Stripe.Product{} = prod ->
          prod

        prod_id when is_binary(prod_id) ->
          {:ok, prod} = Stripe.Product.retrieve(prod_id)
          prod
      end

    metadata = Map.merge(product.metadata || %{}, price.metadata || %{})
    recurring = price.recurring || %{}

    tiers =
      (price.tiers || [])
      |> Enum.map(fn
        %_struct{} = tier -> Map.from_struct(tier)
        tier when is_map(tier) -> tier
      end)

    attrs = %{
      stripe_price_id: price.id,
      stripe_product_id: product.id,
      name: product.name,
      description: product.description,
      unit_amount: price.unit_amount,
      unit_amount_decimal: price.unit_amount_decimal,
      currency: price.currency,
      interval: Map.get(recurring, :interval),
      billing_scheme: price.billing_scheme || "per_unit",
      usage_type: Map.get(recurring, :usage_type) || "licensed",
      meter_event_name: resolve_meter_event_name(metadata, recurring),
      tiers: tiers,
      active: price.active && product.active,
      metadata: metadata
    }

    plan_schema
    |> struct()
    |> plan_schema.changeset(attrs)
    |> Bling.repo().insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :stripe_price_id
    )
  end

  def list_pricing_tiers do
    active_plans = list_active()

    {licensed, metered} =
      Enum.split_with(active_plans, fn plan -> plan.usage_type == "licensed" end)

    overages_by_product = Enum.group_by(metered, & &1.stripe_product_id)

    Enum.map(licensed, fn base_plan ->
      %{
        plan: base_plan,
        overages: Map.get(overages_by_product, base_plan.stripe_product_id, [])
      }
    end)
  end

  defp resolve_meter_event_name(%{"meter_event_name" => name}, _recurring)
       when is_binary(name) and name != "" do
    name
  end

  defp resolve_meter_event_name(_metadata, %{meter: meter_id})
       when is_binary(meter_id) and meter_id != "" do
    case Stripe.Billing.Meter.retrieve(meter_id) do
      {:ok, %{event_name: event_name}} -> event_name
      _ -> nil
    end
  end

  defp resolve_meter_event_name(_, _), do: nil
end
