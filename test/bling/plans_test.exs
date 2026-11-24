defmodule Bling.PlansTest do
  use ExUnit.Case, async: false

  alias Bling.Plans

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(BlingTest.Repo)
    :ok
  end

  describe "upsert_from_stripe/1" do
    test "inserts a licensed price and updates it on conflict" do
      {:ok, product} = Stripe.Product.create(%{name: "Test Licensed Plan", metadata: %{"tier" => "pro"}})
      {:ok, price} =
        Stripe.Price.create(%{
          product: product.id,
          unit_amount: 1900,
          currency: "usd",
          recurring: %{interval: "month", usage_type: "licensed"}
        })

      expanded_price = %{price | product: product}
      assert {:ok, plan} = Plans.upsert_from_stripe(expanded_price)
      assert plan.stripe_price_id == price.id
      assert plan.stripe_product_id == product.id
      assert plan.name == "Test Licensed Plan"
      assert plan.unit_amount == 1900
      assert plan.interval == "month"
      assert plan.usage_type == "licensed"
      assert plan.metadata == %{"tier" => "pro"}

      # Updating name and re-upserting should update existing row without duplicating
      updated_price = %{expanded_price | product: %{product | name: "Renamed Pro Plan"}}
      assert {:ok, updated_plan} = Plans.upsert_from_stripe(updated_price)
      assert updated_plan.id == plan.id
      assert updated_plan.name == "Renamed Pro Plan"

      assert length(Plans.list_active()) == 1
    end

    test "syncs a metered price with meter_event_name metadata" do
      {:ok, product} =
        Stripe.Product.create(%{
          name: "API Overage",
          metadata: %{"meter_event_name" => "api_requests"}
        })

      {:ok, meter} =
        Stripe.Request.new_request(%{})
        |> Stripe.Request.put_endpoint("billing/meters")
        |> Stripe.Request.put_method(:post)
        |> Stripe.Request.put_params(%{
          display_name: "Test API Meter #{System.unique_integer([:positive])}",
          event_name: "api_requests_#{System.unique_integer([:positive])}",
          default_aggregation: %{formula: "sum"}
        })
        |> Stripe.Request.make_request()

      {:ok, price} =
        Stripe.Price.create(%{
          product: product.id,
          unit_amount: 5,
          currency: "usd",
          recurring: %{interval: "month", usage_type: "metered", meter: meter["id"]}
        })

      expanded_price = %{price | product: product}
      assert {:ok, plan} = Plans.upsert_from_stripe(expanded_price)
      assert plan.usage_type == "metered"
      assert plan.meter_event_name == "api_requests"
    end
  end

  describe "sync_all/1" do
    test "pulls active prices from Stripe into the database" do
      assert :ok = Plans.sync_all(%{limit: 5})
      plans = Plans.list_active()
      assert is_list(plans)
    end
  end
end
