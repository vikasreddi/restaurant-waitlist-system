# Symmetric adjacency between two tables, stored canonically: table_id is
# always the lower id, adjacent_table_id the higher one (enforced by a DB check
# constraint). This is what prevents "T01<->T02" from ever being representable
# as two independent rows — there is exactly one valid row for any given pair.
#
# Use TableAdjacency.pair! to create a row without having to know which side is
# "lower" — it sorts the two tables itself.
class TableAdjacency < ApplicationRecord
  belongs_to :table
  belongs_to :adjacent_table, class_name: "Table"

  validates :table_id, uniqueness: { scope: :adjacent_table_id }
  validate :not_self_adjacent

  def self.pair!(table_a, table_b)
    lower, higher = [table_a, table_b].sort_by(&:id)
    create!(table: lower, adjacent_table: higher)
  end

  private

  def not_self_adjacent
    errors.add(:adjacent_table_id, "can't be the same table") if table_id.present? && table_id == adjacent_table_id
  end
end
