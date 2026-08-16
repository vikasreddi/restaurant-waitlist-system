class CreateSeatingAssignmentTables < ActiveRecord::Migration[7.1]
  def change
    create_table :seating_assignment_tables do |t|
      t.references :seating_assignment, null: false, foreign_key: true
      t.references :table, null: false, foreign_key: true
      t.datetime :released_at

      t.timestamps
    end

    # THE core exclusivity constraint of the whole schema (INV-001/002/003, INV-016).
    # Finalized design after a real, caught mistake — see
    # 06-ai-working-record/ai-corrections.md CORR-004: an earlier draft predicated
    # this index on a `status` column meant to mirror the parent SeatingAssignment's
    # status, which PostgreSQL partial indexes cannot reference (predicates may only
    # use columns of the table being indexed). `released_at` lives on THIS table, so
    # this predicate is self-contained and needs no application-level sync promise.
    add_index :seating_assignment_tables, :table_id, unique: true,
      where: "released_at IS NULL", name: "index_seating_assignment_tables_on_claimed_table"
  end
end
