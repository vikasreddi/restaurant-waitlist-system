require "test_helper"

module Allocation
  # Real PostgreSQL concurrency, not mocked locks — same pattern established
  # by Guest::JoinService's concurrency test (Phase 5B.3): real threads, each
  # with its own live connection, a Queue-based start barrier so both sides
  # begin as close together as possible, and use_transactional_tests = false
  # so each thread's writes are actually visible across connections instead
  # of being trapped inside one rolled-back wrapper transaction.
  #
  # Because use_transactional_tests is off, this class cannot rely on
  # automatic rollback to isolate itself from other tests the way every
  # other test file in this project does — every other file's Table/
  # TableAdjacency writes (including seed loading) live inside a per-test
  # transaction that gets rolled back afterward, which is *why* the test
  # database's real, persisted baseline for Table/TableAdjacency is empty,
  # not the 40/19 seed set (db:seed is a development/production step; tests
  # that need seed data load it themselves, transactionally). setup/teardown
  # here explicitly clear this file's own data around every test and leave
  # the database back at that same empty baseline — never reseeding it,
  # since a real (non-rolled-back) load_seed here would permanently leak
  # 40 tables + 19 adjacencies into every other file's supposedly-empty
  # starting state (a real bug this file hit and fixed during development —
  # see ai-corrections.md CORR-007).
  #
  # A related, separate thing this file's development also caught: a free
  # seed 4-seat table legitimately outranks/ties a manufactured 2+2 pair on
  # fit, and the locked tie-break correctly prefers the single table
  # (allocation-algorithm.md §14 working exactly as specified) — which is
  # the other reason this file must fully control its own Table/
  # TableAdjacency state rather than run alongside any leftover data.
  class ReservationServiceConcurrencyTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    NOW = Time.zone.parse("2026-01-01 12:00:00")

    setup do
      SeatingAssignmentTable.delete_all
      SeatingAssignment.delete_all
      QueueEntry.delete_all
      TableAdjacency.delete_all
      Table.delete_all
    end

    teardown do
      SeatingAssignmentTable.delete_all
      SeatingAssignment.delete_all
      QueueEntry.delete_all
      TableAdjacency.delete_all
      Table.delete_all
    end

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
      # #value (not just #join) re-raises any exception the thread raised,
      # instead of Ruby's default of silently swallowing it — a genuine
      # error here must fail the test loudly, not read as a mysteriously
      # missing result.
      threads.each(&:value)

      results
    end

    # --- Test 16 — real concurrent same-table race ---

    test "two concurrent reservation attempts for the same single table: exactly one succeeds" do
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid, joined_at: NOW - 60)
      table = Table.create!(name: "RSC-1", capacity: 2)

      results = run_concurrently(2) { ReservationService.call(now: NOW) }

      successes = results.select(&:success?)
      assert_equal 1, successes.length
      assert_equal 1, SeatingAssignment.where(queue_entry_id: entry.id, status: "pending").count
      assert_equal 1, SeatingAssignmentTable.where(table_id: table.id, released_at: nil).count
      assert_equal "ready", entry.reload.status
    end

    # --- Test 17 — combined-table concurrent race ---

    test "two concurrent reservation attempts for the same adjacent pair: exactly one succeeds, never a partial split" do
      entry = QueueEntry.create!(group_size: 4, phone_number: "555-0100", idempotency_key: SecureRandom.uuid, joined_at: NOW - 60)
      t1 = Table.create!(name: "RSC-2A", capacity: 2)
      t2 = Table.create!(name: "RSC-2B", capacity: 2)
      TableAdjacency.pair!(t1, t2)

      results = run_concurrently(2) { ReservationService.call(now: NOW) }

      successes = results.select(&:success?)
      assert_equal 1, successes.length

      winning_assignment = successes.first.seating_assignment
      claimed_table_ids = winning_assignment.seating_assignment_tables.reload.map(&:table_id).sort
      assert_equal [t1.id, t2.id].sort, claimed_table_ids # both tables, same assignment — never split across two

      assert_equal 1, SeatingAssignment.where(queue_entry_id: entry.id).count
      assert_equal 2, SeatingAssignmentTable.where(table_id: [t1.id, t2.id], released_at: nil).count
      assert_equal "ready", entry.reload.status
    end
  end
end
