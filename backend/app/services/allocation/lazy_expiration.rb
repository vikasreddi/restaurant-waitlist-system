module Allocation
  # DEC-015 lazy READY-expiration check (INV-017) — shared by every read/write
  # that touches a `ready` entry or its assignment, per functional-spec.md
  # §8a: "no scheduler... embedded in an operation that was going to touch
  # the database anyway." Originally duplicated across two call sites
  # (Guest::CurrentQueueStatusService, Staff::ConfirmSeatingService — each
  # explicitly commented "a third call site would tip this toward
  # extraction"). Extracted here now that Staff::QueueViewService (Phase
  # 5B.8) is that third site, per this phase's own explicit instruction to
  # "reuse the existing expiration mechanism... do not create a second
  # expiration implementation."
  #
  # Caller contract: entry must already be locked (SELECT ... FOR UPDATE) by
  # the caller, inside the caller's own transaction — this module performs no
  # locking of its own. Returns true if this call performed the expiration
  # (and its side effects have been persisted), false otherwise.
  module LazyExpiration
    def self.expire_if_overdue!(entry)
      return false unless entry.status == "ready"

      assignment = entry.current_seating_assignment
      return false if assignment.nil? || assignment.expires_at.nil? || Time.current < assignment.expires_at

      assignment.seating_assignment_tables.where(released_at: nil).update_all(released_at: Time.current)
      assignment.update!(status: "released")
      entry.update!(status: "no_show", no_show_at: Time.current)
      true
    end
  end
end
