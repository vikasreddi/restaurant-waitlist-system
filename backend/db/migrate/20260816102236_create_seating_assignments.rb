class CreateSeatingAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :seating_assignments do |t|
      t.references :queue_entry, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"

      # created_at (below) doubles as "reservation made at" (mirrors QueueEntry#ready_at
      # for the same event). expires_at is computed at creation time (ready_at + the
      # configurable READY timeout, DEC-015) so expiry queries don't need to know the
      # current threshold config — a small, deliberate implementation refinement of
      # domain-model-proposal.md §8's "derive, don't store" stance; documented in
      # 06-ai-working-record/agent-decisions.md.
      t.datetime :expires_at
      t.datetime :activated_at
      t.datetime :released_at

      t.timestamps
    end

    # At most one non-released assignment per queue entry (INV-009) — historical
    # released assignments are never blocked from existing alongside this.
    add_index :seating_assignments, :queue_entry_id, unique: true,
      where: "status <> 'released'", name: "index_seating_assignments_on_current_queue_entry"

    add_check_constraint :seating_assignments,
      "status IN ('pending', 'active', 'released')",
      name: "seating_assignments_status_valid"
  end
end
