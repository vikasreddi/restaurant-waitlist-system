# Minimum persisted staff user for the future staff screen. Stub-strength
# authentication is explicitly acceptable (REQ-STAFF-001) — no roles, no
# sessions, no login endpoint here; that belongs to a later phase.
class StaffUser < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true
end
