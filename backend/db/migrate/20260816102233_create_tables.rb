class CreateTables < ActiveRecord::Migration[7.1]
  def change
    create_table :tables do |t|
      t.string :name, null: false
      t.integer :capacity, null: false

      t.timestamps
    end

    add_index :tables, :name, unique: true

    # Deliberately no occupancy/status column here (INV-014/domain-model.md §2) —
    # availability is always derived from seating_assignment_tables.
    add_check_constraint :tables, "capacity > 0", name: "tables_capacity_positive"
  end
end
