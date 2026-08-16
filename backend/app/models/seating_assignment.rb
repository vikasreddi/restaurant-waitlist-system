# A reservation/occupancy record for one QueueEntry, covering 1-2 tables.
# pending  = allocation reserved the configuration; QueueEntry is `ready`.
# active   = staff confirmed the seating code; QueueEntry is `seated`.
# released = group left, was marked no-show, or the reservation expired
#            (DEC-015) — the row is kept (never deleted) so historical
#            assignments remain queryable; see SeatingAssignmentTable.
#
# Deliberately NOT implemented here (later phases): the allocation service that
# creates these atomically with their SeatingAssignmentTable rows, staff
# confirmation, and the lazy expiration check itself (only the data it needs is
# persisted: expires_at, computed below).
class SeatingAssignment < ApplicationRecord
  STATUSES = %w[pending active released].freeze

  # Tunable per DEC-015 — illustrated as 5 minutes, not hardcoded into business
  # logic. Read from ENV so it can be adjusted per environment without a code
  # change.
  READY_TIMEOUT = ENV.fetch("READY_TIMEOUT_SECONDS", 300).to_i.seconds

  belongs_to :queue_entry
  has_many :seating_assignment_tables
  has_many :tables, through: :seating_assignment_tables

  before_validation :set_expires_at, on: :create

  validates :status, inclusion: { in: STATUSES }
  validates :queue_entry_id, uniqueness: { conditions: -> { where.not(status: "released") } }

  private

  def set_expires_at
    # Frozen at creation time from the current READY_TIMEOUT, rather than
    # recomputed from queue_entry.ready_at + a live config read on every check —
    # a small, deliberate refinement of domain-model-proposal.md §8's
    # "derive, don't store" stance for the starvation threshold (see
    # 06-ai-working-record/agent-decisions.md for why this one field differs).
    self.expires_at ||= Time.current + READY_TIMEOUT
  end
end
