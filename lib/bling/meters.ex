defmodule Bling.Meters do
  @doc """
  Records a metered usage event in Stripe for a Bling customer.

  ## Example
      Bling.Meters.record_event(user, "api_overage", 15, identifier: "req_uuid_123")
  """
  def record_event(%{stripe_id: stripe_customer_id}, event_name, value \\ 1, opts \\ [])
      when is_binary(stripe_customer_id) do
    timestamp = Keyword.get(opts, :timestamp, System.os_time(:second))
    identifier = Keyword.get(opts, :identifier)

    body =
      %{
        event_name: event_name,
        timestamp: timestamp,
        payload: %{
          stripe_customer_id: stripe_customer_id,
          value: to_string(value)
        }
      }
      |> maybe_put(:identifier, identifier)

    Stripe.Request.new_request(opts[:stripe] || %{})
    |> Stripe.Request.put_endpoint("billing/meter_events")
    |> Stripe.Request.put_method(:post)
    |> Stripe.Request.put_params(body)
    |> Stripe.Request.make_request()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
