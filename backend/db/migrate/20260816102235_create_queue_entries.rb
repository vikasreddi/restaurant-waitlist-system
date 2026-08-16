class CreateQueueEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :queue_entries do |t|
      t.integer :group_size, null: false
      t.string :phone_number, null: false
      t.string :status, null: false, default: "waiting"

      # Opaque, unguessable identifiers — see functional-spec.md §9/§10. Neither is
      # derived from phone number or from this row's own id (REQ-IMP-003, DEC-006/007).
      t.string :active_visit_token, null: false
      t.string :idempotency_key, null: false

      # Set only on entering `ready` (allocation-spec.md §5). OPEN-005: exact format
      # is still an open decision — persisted here as an opaque string regardless.
      t.string :seating_code

      t.datetime :joined_at, null: false
      t.datetime :ready_at
      t.datetime :seated_at
      t.datetime :left_at
      t.datetime :no_show_at

      t.timestamps
    end

    add_index :queue_entries, :active_visit_token, unique: true
    add_index :queue_entries, :idempotency_key, unique: true
    add_index :queue_entries, [:status, :joined_at]

    # Staff "seat by code" lookup, and the no-collision guarantee between
    # simultaneously-ready groups (api-spec.md, domain-model-proposal.md §5).
    add_index :queue_entries, :seating_code, unique: true, where: "seating_code IS NOT NULL"

    add_check_constraint :queue_entries, "group_size > 0", name: "queue_entries_group_size_positive"
    add_check_constraint :queue_entries,
      "status IN ('waiting', 'ready', 'seated', 'left', 'no_show')",
      name: "queue_entries_status_valid"
  end
end
