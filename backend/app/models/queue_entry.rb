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
  validates :idempotency_key, presence: true, uniqueness: true

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
