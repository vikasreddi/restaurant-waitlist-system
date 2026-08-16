# A physical table: identifier + capacity only. Deliberately no occupancy field
# (INV-014, domain-model.md §2) — availability is always derived by checking
# whether a non-released SeatingAssignmentTable row references this table.
class Table < ApplicationRecord
  has_many :seating_assignment_tables
  has_many :seating_assignments, through: :seating_assignment_tables

  # Adjacency is stored canonically (table_id < adjacent_table_id, enforced by a
  # DB check constraint on table_adjacencies) so a pair is never representable as
  # two independent rows. These two associations expose the "as lower" and
  # "as higher" half of that storage; #adjacent_tables hides the detail behind a
  # single, symmetric, readable method.
  has_many :adjacencies_as_lower, class_name: "TableAdjacency", foreign_key: :table_id, inverse_of: :table
  has_many :adjacencies_as_higher, class_name: "TableAdjacency", foreign_key: :adjacent_table_id, inverse_of: :adjacent_table

  validates :name, presence: true, uniqueness: true
  validates :capacity, numericality: { greater_than: 0 }

  def adjacent_tables
    Table.where(id: adjacencies_as_lower.select(:adjacent_table_id))
      .or(Table.where(id: adjacencies_as_higher.select(:table_id)))
  end

  # True iff no non-released SeatingAssignmentTable claim currently references
  # this table. The database-level guarantee this reflects lives on
  # SeatingAssignmentTable's partial unique index, not here — this is a
  # convenience read, not the source of truth.
  def free?
    !seating_assignment_tables.where(released_at: nil).exists?
  end
end
