class CreateTableAdjacencies < ActiveRecord::Migration[7.1]
  def change
    create_table :table_adjacencies do |t|
      t.references :table, null: false, foreign_key: { to_table: :tables }
      t.references :adjacent_table, null: false, foreign_key: { to_table: :tables }

      t.timestamps
    end

    add_index :table_adjacencies, [:table_id, :adjacent_table_id], unique: true, name: "index_table_adjacencies_on_pair"

    # Canonical pair representation: only (lower_id, higher_id) is ever a valid row.
    # This is what actually prevents "T01<->T02" from being representable as two
    # independent rows (T01,T02) and (T02,T01) — a single check constraint, not
    # application-level deduplication logic.
    add_check_constraint :table_adjacencies, "table_id < adjacent_table_id", name: "table_adjacencies_canonical_order"
  end
end
