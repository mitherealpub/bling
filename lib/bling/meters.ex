defmodule Bling.Meters do
  @moduledoc """
  Records and inspects metered usage events via `stripity_stripe`'s
  `Stripe.Billing.MeterEvent` and `Stripe.Billing.MeterEventSummary` APIs.
  """

  @doc """
  Records a metered usage event in Stripe for a Bling customer.

  ## Options
    * `:timestamp` - Unix timestamp in seconds (defaults to current OS time)
    * `:identifier` - Unique idempotency identifier for the event
    * `:stripe` - Keyword list or map of `stripity_stripe` request options (e.g., `api_key: ...`)

  ## Example
      Bling.Meters.record_event(user, "api_overage", 15, identifier: "req_uuid_123")
  """
  def record_event(customer, event_name, value \\ 1, opts \\ [])

  def record_event(%{stripe_id: nil}, _event_name, _value, _opts) do
    {:error, :no_stripe_customer}
  end

  def record_event(%{stripe_id: stripe_customer_id}, event_name, value, opts)
      when is_binary(stripe_customer_id) do
    timestamp = Keyword.get(opts, :timestamp, System.os_time(:second))
    identifier = Keyword.get(opts, :identifier)
    stripe_opts = Keyword.get(opts, :stripe, []) |> Keyword.new()

    params =
      %{
        event_name: event_name,
        timestamp: timestamp,
        payload: %{
          "stripe_customer_id" => stripe_customer_id,
          "value" => to_string(value)
        }
      }
      |> maybe_put(:identifier, identifier)

    Stripe.Billing.MeterEvent.create(params, stripe_opts)
  end

  @doc """
  Cancels a previously reported meter event by its `identifier`.
  """
  def cancel_event(event_name, identifier, opts \\ []) do
    stripe_opts = Keyword.get(opts, :stripe, []) |> Keyword.new()

    Stripe.Billing.MeterEventAdjustment.create(
      %{
        event_name: event_name,
        type: "cancel",
        cancel: %{identifier: identifier}
      },
      stripe_opts
    )
  end

  @doc """
  Lists aggregated meter event summaries for a customer over a time window.
  """
  def list_summaries(meter_id, %{stripe_id: stripe_customer_id}, start_time, end_time, opts \\ [])
      when is_binary(stripe_customer_id) do
    stripe_opts = Keyword.get(opts, :stripe, []) |> Keyword.new()

    params =
      %{
        customer: stripe_customer_id,
        start_time: start_time,
        end_time: end_time
      }
      |> maybe_put(:value_grouping_window, Keyword.get(opts, :value_grouping_window))

    Stripe.Billing.MeterEventSummary.list(meter_id, params, stripe_opts)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
