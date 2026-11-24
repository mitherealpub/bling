defmodule Bling.StripeWebhookHandler do
  @moduledoc """
  Handles Stripe webhooks for customer, price, product, and subscription events.
  See the source file for full implementation details and usage with `Stripe.WebhookPlug`.
  """

  alias Bling.Customers
  alias Bling.Plans
  alias Bling.Subscriptions

  def handle_event(event) do
    bling = Bling.bling()
    handle(event.type, event.data.object)
    Bling.Util.maybe_call({bling, :handle_stripe_webhook_event, [event]})
  end

  defp handle("customer.deleted", %Stripe.Customer{} = event) do
    customer = Bling.customer_from_stripe_id(event.id)
    if customer do
      customer |> Customers.subscriptions() |> Enum.each(&Subscriptions.mark_as_cancelled/1)
      customer
      |> Ecto.Changeset.change(%{stripe_id: nil, payment_id: nil, payment_last_four: nil, payment_type: nil})
      |> Bling.repo().update!()
    end
    :ok
  end

  defp handle("customer.updated", %Stripe.Customer{} = event) do
    Customers.update_default_payment_method_from_stripe(Bling.customer_from_stripe_id(event.id))
    :ok
  end

  defp handle(type, %Stripe.Price{} = price) when type in ["price.created", "price.updated", "price.deleted"] do
    Plans.upsert_from_stripe(price)
    :ok
  end

  defp handle("product.updated", %Stripe.Product{} = _product) do
    Plans.sync_all()
    :ok
  end

  defp handle("customer.subscription.created", %Stripe.Subscription{} = event) do
    repo = Bling.repo()
    sub_schema = Bling.subscription()
    unless repo.get_by(sub_schema, stripe_id: event.id) do
      customer = Bling.customer_from_stripe_id(event.customer)
      subscription = customer
        |> Ecto.build_assoc(:subscriptions)
        |> Subscriptions.subscription_struct_from_stripe_subscription(event)
        |> repo.insert!()
      Subscriptions.subscription_item_structs_from_stripe_items(event.items.data, subscription)
      |> Enum.each(&repo.insert!/1)
    end
    :ok
  end

  defp handle("customer.subscription.deleted", %Stripe.Subscription{} = event) do
    repo = Bling.repo()
    if subscription = repo.get_by(Bling.subscription(), stripe_id: event.id) do
      Subscriptions.mark_as_cancelled(subscription)
    end
    :ok
  end

  defp handle("customer.subscription.updated", %Stripe.Subscription{} = event) do
    repo = Bling.repo()
    if subscription = repo.get_by(Bling.subscription(), stripe_id: event.id) do
      if event.status == "incomplete_expired" do
        repo.delete(subscription)
      else
        subscription = subscription
        |> Subscriptions.subscription_struct_from_stripe_subscription(event)
        |> repo.update!()
        
        Subscriptions.subscription_item_structs_from_stripe_items(event.items.data, subscription)
        |> Enum.each(fn item -> repo.insert!(item, on_conflict: :replace_all, conflict_target: [:stripe_id]) end)

        import Ecto.Query, only: [from: 2]
        item_ids = Enum.map(event.items.data, & &1.id)
        from(s in Bling.subscription_item(), where: s.subscription_id == ^subscription.id and s.stripe_id not in ^item_ids)
        |> repo.delete_all()
      end
    end
    :ok
  end

  defp handle(_event_name, _event_object), do: :ok
end
