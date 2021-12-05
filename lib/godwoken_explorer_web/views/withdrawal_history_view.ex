defmodule GodwokenExplorer.WithdrawalHistoryView do
  use JSONAPI.View, type: "withdrawal_history"
  use Retry

  use GodwokenExplorer, :schema

  def fields do
    [:layer1_block_number, :layer1_tx_hash, :layer1_output_index, :l2_script_hash, :block_hash, :block_number, :udt_script_hash, :sell_amount, :sell_capacity, :owner_lock_hash, :payment_lock_hash, :amount, :udt_id, :timestamp, :state]
  end

  def relationships do
    [udt: {GodwokenExplorer.UDTView, :include}]
  end

  def find_by_owner_lock_hash(owner_lock_hash, page) do
    query_results =
      from(h in WithdrawalHistory,
        preload: [:udt],
        where:
          h.owner_lock_hash == ^owner_lock_hash, order_by: [desc: :id]
      )
      |> Repo.paginate(page: page)

    succeed_history_ids =
      query_results.entries
      |> Enum.filter(fn h -> h.state == :pending end)
      |> Enum.map(fn h ->
        result = retry with: constant_backoff(500) |> Stream.take(3) do
          GodwokenRPC.fetch_live_cell(h.layer1_output_index, h.layer1_tx_hash)
        after
          result -> result
        else
          error -> {:ok, true}
        end

        if !elem(result, 1) do
          h.id
        end
      end)
      |> Enum.filter(& !is_nil(&1))

    if length(succeed_history_ids) > 0 do
      from(h in WithdrawalHistory, where: h.id in ^succeed_history_ids) |> Repo.update_all(set: [state: :succeed])
      from(h in WithdrawalHistory,
        preload: [:udt],
        where:
          h.owner_lock_hash == ^owner_lock_hash, order_by: [desc: :id]
      )
      |> Repo.paginate(page: page)
    else
      query_results
    end
  end
end