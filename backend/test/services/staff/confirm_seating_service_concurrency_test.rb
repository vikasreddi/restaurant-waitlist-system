require "test_helper"

module Staff
  # Real PostgreSQL concurrency, not mocked locks — same pattern established
  # by Guest::JoinServiceConcurrencyTest (Phase 5B.3) and
  # Allocation::ReservationServiceConcurrencyTest (Phase 5B.5.3): real
  # threads, each with its own live connection, a Queue-based start barrier,
  # use_transactional_tests = false so writes are actually visible across
  # connections.
  class ConfirmSeatingServiceConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    def run_concurrently(count)
      ready = Queue.new
      go = Queue.new
      results = []
      results_mutex = Mutex.new

      threads = count.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            go.pop
            result = yield
            results_mutex.synchronize { results << result }
          end
        end
      end

      count.times { ready.pop }
      count.times { go << true }
      threads.each(&:value)

      results
    end

    test "two concurrent confirmation requests for the same seating code: exactly one succeeds" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      entry.update!(status: "ready", ready_at: Time.current, seating_code: "RACE001")
      table = Table.create!(name: "CSC-#{SecureRandom.hex(4)}", capacity: 2)
      assignment = SeatingAssignment.create!(queue_entry: entry, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)

      results = run_concurrently(2) { ConfirmSeatingService.call(seating_code: "RACE001") }

      outcomes = results.map(&:outcome).sort_by(&:to_s)
      assert_equal [:already_confirmed, :success], outcomes

      assert_equal "seated", entry.reload.status
      assert_equal "active", assignment.reload.status
      assert_equal 1, SeatingAssignment.where(queue_entry_id: entry.id).count
    ensure
      SeatingAssignmentTable.where(seating_assignment_id: SeatingAssignment.where(queue_entry_id: entry.id).select(:id)).delete_all
      SeatingAssignment.where(queue_entry_id: entry.id).delete_all
      QueueEntry.where(id: entry.id).delete_all
      Table.where(id: table.id).delete_all
    end
  end
end
