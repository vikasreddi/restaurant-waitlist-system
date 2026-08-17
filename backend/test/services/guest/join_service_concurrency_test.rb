require "test_helper"

module Guest
  # A genuine concurrency test needs two things a normal transactional test
  # can't give it: real parallel execution (not two sequential calls that
  # happen to run one after another), and its own DB connections that aren't
  # wrapped in the same rolled-back transaction. See this project's own
  # hard-path-testing skill for why `use_transactional_tests = false` here is
  # expected, not a mistake to "fix".
  class JoinServiceConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    test "two concurrent join requests with the same idempotency key produce exactly one QueueEntry" do
      # DEC-011 (Phase 5B.12): group_size 2 must be seatable by some valid
      # configuration. use_transactional_tests is false here, so this table
      # (and its claim) must be cleaned up manually below, like the
      # QueueEntry rows already are.
      table = Table.create!(name: "JC-#{SecureRandom.hex(4)}", capacity: 10)
      claimer = QueueEntry.create!(group_size: 2, phone_number: "555-0199", idempotency_key: SecureRandom.uuid)
      claimer.update!(status: "ready", ready_at: Time.current, seating_code: SecureRandom.hex(4))
      claim_assignment = SeatingAssignment.create!(queue_entry: claimer, status: "pending")
      SeatingAssignmentTable.create!(seating_assignment: claim_assignment, table: table)

      key = SecureRandom.uuid
      ready = Queue.new
      go = Queue.new
      results = []
      results_mutex = Mutex.new

      # Honest limitation (governing prompt §12): this synchronizes both
      # threads to start as close together as possible via the ready/go
      # handshake below, but Ruby/Postgres give no hard guarantee the two
      # `create!` calls land in the exact same instant. The test's assertions
      # hold regardless of how much overlap actually occurs — if they truly
      # race, the database's unique constraint (not this test) is what
      # guarantees only one commit succeeds and the other resolves via the
      # ActiveRecord::RecordNotUnique rescue in JoinService; if the OS happens
      # to schedule them sequentially instead, the second one correctly takes
      # the ordinary find_by-existing path in JoinService#call instead. Either
      # way, the invariant under test — exactly one QueueEntry for this key —
      # holds, so this is a real test of the invariant even though it can't
      # force true simultaneity on every run.
      threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            go.pop
            result = JoinService.call(group_size: 2, phone_number: "555-0100", idempotency_key: key)
            results_mutex.synchronize { results << result }
          end
        end
      end

      2.times { ready.pop } # block until both threads hold a live DB connection
      2.times { go << true } # release both as close together as possible

      threads.each(&:join)

      assert_equal 1, QueueEntry.where(idempotency_key: key).count
      assert_equal [:created, :idempotent_replay], results.map(&:outcome).sort_by(&:to_s)
    ensure
      QueueEntry.where(idempotency_key: key).delete_all
      SeatingAssignmentTable.where(seating_assignment_id: claim_assignment&.id).delete_all
      claim_assignment&.destroy
      claimer&.destroy
      table&.destroy
    end
  end
end
