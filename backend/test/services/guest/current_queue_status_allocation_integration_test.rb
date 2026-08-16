require "test_helper"

module Guest
  # Phase 5B.5.4 — verifies that DEC-015's lazy READY-expiration path (the
  # "no-show" allocation trigger, this phase's governing prompt §15/§17)
  # actually invokes Allocation::Orchestrator once its release commits, so a
  # waiting group can fill the newly-freed table without any background job.
  class CurrentQueueStatusAllocationIntegrationTest < ActiveSupport::TestCase
    NOW = Time.zone.parse("2026-01-01 12:00:00")

    def build_ready_entry(expires_at:)
      table = Table.create!(name: "AE-#{SecureRandom.hex(4)}", capacity: 2)
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: NOW, seating_code: SecureRandom.hex(4))
      assignment = SeatingAssignment.create!(queue_entry: entry, expires_at: expires_at)
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
      [entry, table]
    end

    test "an overdue ready entry's expiration frees its table, and a waiting group is allocated to it" do
      expired_entry, freed_table = build_ready_entry(expires_at: 1.minute.ago)
      waiting_entry = QueueEntry.create!(group_size: 2, phone_number: "555-0200", idempotency_key: SecureRandom.uuid)

      Guest::CurrentQueueStatusService.call(active_visit_token: expired_entry.active_visit_token)

      assert_equal "no_show", expired_entry.reload.status

      # The table is briefly free between the expiration release and the
      # orchestrator's own reservation, both within this single call — not
      # separately observable from outside. The externally-visible proof is
      # that the table ends up claimed by the WAITING group's new
      # assignment, not still held by the expired one and not sitting idle.
      assert_equal "ready", waiting_entry.reload.status
      assignment = SeatingAssignment.find_by(queue_entry_id: waiting_entry.id)
      assert_equal [freed_table.id], assignment.seating_assignment_tables.map(&:table_id)
      assert_equal "released", SeatingAssignment.find_by(queue_entry_id: expired_entry.id).status
    end

    test "reading a ready entry that is NOT yet overdue never invokes allocation for other waiting groups" do
      entry, table = build_ready_entry(expires_at: 10.minutes.from_now)
      waiting_entry = QueueEntry.create!(group_size: 2, phone_number: "555-0300", idempotency_key: SecureRandom.uuid)

      Guest::CurrentQueueStatusService.call(active_visit_token: entry.active_visit_token)

      assert_equal "ready", entry.reload.status
      assert_not table.reload.free? # still held by the original entry
      assert_equal "waiting", waiting_entry.reload.status # untouched — no allocation ran
    end
  end
end
