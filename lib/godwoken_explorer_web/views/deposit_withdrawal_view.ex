defmodule GodwokenExplorer.DepositWithdrawalView do
  use GodwokenExplorer, :schema

  def list_by_block_number(block_number, page) do
    parsed_struct =
      withdrawal_base_query(dynamic([w], w.block_number == ^block_number))
      |> order_by(desc: :inserted_at)
      |> Repo.paginate(page: page)

    %{
      page: parsed_struct.page_number,
      total_count: parsed_struct.total_entries,
      data: parsed_struct.entries
    }
  end

  def list_by_udt_id(udt_id, page) do
    deposits =
      deposit_base_query(dynamic([d], d.udt_id == ^udt_id))

    withdrawals =
      withdrawal_base_query(
        dynamic([w], w.udt_id == ^udt_id)
      )

    original_struct =
      from(q in subquery(deposits |> union_all(^withdrawals)), order_by: [desc: q.timestamp])

    parse_struct(original_struct, page)
  end

  def list_by_script_hash(script_hash, page) do
    deposits = deposit_base_query(dynamic([d], d.script_hash == ^script_hash))
    withdrawals = withdrawal_base_query(dynamic([w], w.l2_script_hash == ^script_hash))

    original_struct =
      from(q in subquery(deposits |> union_all(^withdrawals)), order_by: [desc: q.timestamp])

    parse_struct(original_struct, page)
  end

  @spec parse_struct(any, any) :: %{data: any, page: binary, total_count: binary}
  def parse_struct(original_struct, page) do
    parsed_struct = Repo.paginate(original_struct, page: page)

    %{
      page: Integer.to_string(parsed_struct.page_number),
      total_count: Integer.to_string(parsed_struct.total_entries),
      data: parsed_struct.entries
    }
  end

  def withdrawal_base_query(condition) do
    from(w in WithdrawalHistory,
      join: u in UDT,
      on: u.id == w.udt_id,
      join: a2 in Account,
      on: a2.script_hash == w.l2_script_hash,
      where: ^condition,
      select: %{
        script_hash: w.l2_script_hash,
        eth_address: a2.eth_address,
        value: fragment("? / power(10, ?)::decimal", w.amount, u.decimal),
        owner_lock_hash: w.owner_lock_hash,
        payment_lock_hash: w.payment_lock_hash,
        sell_value: fragment("? / power(10, ?)::decimal", w.sell_amount, u.decimal),
        sell_capacity: w.sell_capacity,
        sudt_script_hash: w.udt_script_hash,
        udt_id: w.udt_id,
        udt_name: u.name,
        udt_symbol: u.symbol,
        udt_icon: u.icon,
        block_hash: w.block_hash,
        block_number: w.block_number,
        timestamp: w.timestamp,
        layer1_block_number: w.layer1_block_number,
        layer1_tx_hash: w.layer1_tx_hash,
        layer1_output_index: w.layer1_output_index,
        ckb_lock_hash: nil,
        state: w.state,
        type: "withdrawal"
      }
    )
  end

  def deposit_base_query(condition) do
    from(d in DepositHistory,
      join: u in UDT,
      on: u.id == d.udt_id,
      join: a2 in Account,
      on: a2.script_hash == d.script_hash,
      where: ^condition,
      select: %{
        script_hash: d.script_hash,
        eth_address: a2.eth_address,
        value: fragment("? / power(10, ?)::decimal", d.amount, u.decimal),
        owner_lock_hash: nil,
        payment_lock_hash: nil,
        sell_value: nil,
        sell_capacity: nil,
        sudt_script_hash: nil,
        udt_id: d.udt_id,
        udt_name: u.name,
        udt_symbol: u.symbol,
        udt_icon: u.icon,
        block_hash: nil,
        block_number: nil,
        timestamp: d.timestamp,
        layer1_block_number: d.layer1_block_number,
        layer1_tx_hash: d.layer1_tx_hash,
        layer1_output_index: d.layer1_output_index,
        ckb_lock_hash: d.ckb_lock_hash,
        state: "succeed",
        type: "deposit"
      }
    )
  end
end