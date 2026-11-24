defmodule Bling.MetersTest do
  use ExUnit.Case, async: false

  alias Bling.Meters

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(BlingTest.Repo)
    :ok
  end

  describe "record_event/4" do
    test "returns {:error, :no_stripe_customer} when customer has no stripe_id" do
      customer = %{stripe_id: nil}
      assert {:error, :no_stripe_customer} = Meters.record_event(customer, "api_overage", 10)
    end

    test "sends a meter event to Stripe for a valid customer" do
      event_name = "test_meter_#{System.unique_integer([:positive])}"

      {:ok, _meter} =
        Stripe.Request.new_request(%{})
        |> Stripe.Request.put_endpoint("billing/meters")
        |> Stripe.Request.put_method(:post)
        |> Stripe.Request.put_params(%{
          display_name: "Test Meter #{event_name}",
          event_name: event_name,
          default_aggregation: %{formula: "sum"}
        })
        |> Stripe.Request.make_request()

      {:ok, stripe_customer} = Stripe.Customer.create(%{email: "meter-test@example.com"})
      customer = %{stripe_id: stripe_customer.id}
      identifier = "evt_#{System.unique_integer([:positive])}"

      assert {:ok, response} =
               Meters.record_event(customer, event_name, 25, identifier: identifier)

      assert response["identifier"] == identifier
    end
  end
end
