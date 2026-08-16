# One group's waitlist record. See documents/03-architecture/domain-model.md
# for the authoritative state machine and documents/05-specifications/
# functional-spec.md for the behavior each transition implements.
#
# Deliberately NOT implemented here (later phases): the allocation algorithm,
# staff confirmation, join/position/leave APIs, lazy expiration logic. This
# model is the persistence foundation those will be built on.
class QueueEntry < ApplicationRecord
  STATUSES = %w[waiting ready seated left no_show].freeze

  # A group has at most one *current* (non-released) reservation at a time —
  # enforced at the database level on seating_assignments, not here. Historical
  # released assignments may remain associated with this entry.
  has_many :seating_assignments
  has_one :current_seating_assignment,
    -> { where(status: %w[pending active]) },
    class_name: "SeatingAssignment"

  before_validation :generate_active_visit_token, on: :create
  before_validation :set_joined_at, on: :create

  validates :group_size, numericality: { greater_than: 0 }
  validates :phone_number, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :active_visit_token, presence: true, uniqueness: true
  # idempotency_key is supplied by the client (functional-spec.md §1) — never
  # generated server-side.
  #
  # Deliberately presence-only, NOT `uniqueness: true` — see
  # 06-ai-working-record/ai-corrections.md CORR-005. A Rails uniqueness
  # validation runs a SELECT before the INSERT, so under real concurrency it
  # can win the race against the database's own unique index and raise
  # ActiveRecord::RecordInvalid instead of ActiveRecord::RecordNotUnique,
  # depending on timing — two different exception types for the exact same
  # "this key already exists" case. The database's unique index on
  # idempotency_key (see the migration) is the single, self-contained source
  # of truth for this invariant; Guest::JoinService rescues
  # ActiveRecord::RecordNotUnique directly rather than depending on a
  # second, racy application-level check.
  validates :idempotency_key, presence: true

  private

  def generate_active_visit_token
    # Opaque, unpredictable, non-sequential, never derived from phone number or
    # from this record's own id (functional-spec.md §9, DEC-006).
    self.active_visit_token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_joined_at
    self.joined_at ||= Time.current
  end
end
