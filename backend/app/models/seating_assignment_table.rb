# Which table(s) a SeatingAssignment covers. This is the row that carries the
# database-level table-exclusivity guarantee — see the partial unique index on
# `table_id WHERE released_at IS NULL` in the migration, and
# 06-ai-working-record/ai-corrections.md CORR-004 for why it's shaped this way.
#
# Rows are never deleted (released_at is set instead) — historical assignments
# remain queryable after release.
class SeatingAssignmentTable < ApplicationRecord
  belongs_to :seating_assignment
  belongs_to :table

  # Cheap defense-in-depth at the Rails level for the same invariant the DB's
  # partial unique index enforces authoritatively (INV-001/002/003, INV-016).
  # This validation is NOT what makes the guarantee hold under concurrency —
  # the database constraint is — but it gives a friendlier error in the common
  # single-request case rather than always surfacing a raw constraint violation.
  validate :table_not_already_claimed, on: :create

  # DEC-002 / INV-012: at most two tables per assignment. Application-level only
  # (no DB trigger) — the allocation service is the sole writer of these rows,
  # and this is a fixed, unchanging business rule, not a concurrency-sensitive
  # invariant (see domain-model-proposal.md §2 for why a trigger wasn't judged
  # worth the added migration complexity).
  validate :assignment_has_at_most_two_tables, on: :create

  private

  def table_not_already_claimed
    return if table_id.blank?

    already_claimed = SeatingAssignmentTable.where(table_id: table_id, released_at: nil).exists?
    errors.add(:table_id, "is already claimed by another current seating assignment") if already_claimed
  end

  def assignment_has_at_most_two_tables
    return if seating_assignment_id.blank?

    existing_count = SeatingAssignmentTable.where(seating_assignment_id: seating_assignment_id).count
    errors.add(:seating_assignment_id, "cannot claim more than 2 tables (DEC-002)") if existing_count >= 2
  end
end
