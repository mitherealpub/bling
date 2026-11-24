defmodule Bling.Plans do
  import Ecto.Query
  alias Bling.Plan

  def list_active do
    repo().all(from p in Plan, where: p.active == true, order_by: [asc: p.unit_amount])
  end

  def sync_all(stripe_opts \\ %{}) do
    params = Map.merge(%{active: true, expand: ["data.product"], limit: 100}, stripe_opts)

    with {:ok, %{data: prices}} <- Stripe.Price.list(params) do
      Enum.each(prices, &upsert_from_stripe/1)
      :ok
    end
  end

  def upsert_from_stripe(%Stripe.Price{} = price) do
    product =
      case price.product do
        %Stripe.Product{} = prod -> prod
        prod_id when is_binary(prod_id) ->
          {:ok, prod} = Stripe.Product.retrieve(prod_id)
          prod
      end

    metadata = Map.merge(product.metadata || %{}, price.metadata || %{})

    attrs = %{
      stripe_price_id: price.id,
      stripe_product_id: product.id,
      name: product.name,
      description: product.description,
      unit_amount: price.unit_amount,
      currency: price.currency,
      interval: get_in(price, [Access.key(:recurring), Access.key(:interval)]),
      usage_type: get_in(price, [Access.key(:recurring), Access.key(:usage_type)]) || "licensed",
      meter_event_name: metadata["meter_event_name"],
      active: price.active && product.active,
      metadata: metadata
    }

    %Plan{}
    |> Plan.changeset(attrs)
    |> repo().insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :stripe_price_id
    )
  end

  defp repo, do: Application.fetch_env!(:bling, :repo)
end
