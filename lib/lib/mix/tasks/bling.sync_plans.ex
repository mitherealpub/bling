defmodule Mix.Tasks.Bling.SyncPlans do
  @moduledoc """
  Syncs active products and prices from Stripe into the local plans table.

  ## Usage

      mix bling.sync_plans
  """
  @shortdoc "Syncs active Stripe products and prices into the local plans table."

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    case Bling.Plans.sync_all() do
      :ok ->
        Mix.Shell.IO.info("Stripe plans synced successfully.")

      {:error, error} ->
        Mix.raise("Failed to sync Stripe plans: #{inspect(error)}")
    end
  end
end
