require "test_helper"

module Allocation
  # The one DB-touching piece of the allocation-decision path (see
  # decision_engine_test.rb for the pure engine, tested with no database at
  # all). Uses its own small, deterministic table/adjacency fixture rather
  # than the full seed data, so this test's correctness doesn't depend on the
  # seed distribution.
  class ConfigurationGeneratorTest < ActiveSupport::TestCase
    setup do
      SeatingAssignmentTable.delete_all
      SeatingAssignment.delete_all
      QueueEntry.delete_all
      TableAdjacency.delete_all
      Table.delete_all
    end

    def claim_table!(table)
      entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
      assignment = SeatingAssignment.create!(queue_entry: entry)
      SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)
    end

    test "generates a single configuration for every free table" do
      t1 = Table.create!(name: "GEN-1", capacity: 2)
      t2 = Table.create!(name: "GEN-2", capacity: 4)

      configurations = ConfigurationGenerator.call

      assert_includes configurations.map(&:table_ids), [t1.id]
      assert_includes configurations.map(&:table_ids), [t2.id]
    end

    test "an occupied table produces no single configuration for itself" do
      free = Table.create!(name: "GEN-FREE", capacity: 2)
      occupied = Table.create!(name: "GEN-OCC", capacity: 2)
      claim_table!(occupied)

      configurations = ConfigurationGenerator.call

      assert_includes configurations.map(&:table_ids), [free.id]
      assert_not_includes configurations.map(&:table_ids), [occupied.id]
    end

    test "generates a combined configuration only for an adjacency pair where both members are free" do
      t1 = Table.create!(name: "GEN-A1", capacity: 4)
      t2 = Table.create!(name: "GEN-A2", capacity: 4)
      TableAdjacency.pair!(t1, t2)

      configurations = ConfigurationGenerator.call
      combined = configurations.find { |c| c.table_count == 2 }

      assert combined.present?
      assert_equal [t1.id, t2.id].sort, combined.table_ids
      assert_equal 8, combined.capacity
    end

    test "no combined configuration is generated when one member of the pair is occupied" do
      t1 = Table.create!(name: "GEN-B1", capacity: 4)
      t2 = Table.create!(name: "GEN-B2", capacity: 4)
      TableAdjacency.pair!(t1, t2)
      claim_table!(t2)

      configurations = ConfigurationGenerator.call

      assert_equal 0, configurations.count { |c| c.table_count == 2 }
      # t1 itself is still free and still offered as a single-table option.
      assert_includes configurations.map(&:table_ids), [t1.id]
    end

    test "never generates a reverse-duplicate pair" do
      t1 = Table.create!(name: "GEN-C1", capacity: 2)
      t2 = Table.create!(name: "GEN-C2", capacity: 2)
      TableAdjacency.pair!(t2, t1) # pair! sorts internally regardless of argument order

      configurations = ConfigurationGenerator.call
      combined_ids = configurations.select { |c| c.table_count == 2 }.map(&:table_ids)

      assert_equal [[t1.id, t2.id].sort], combined_ids
    end

    test "never generates a 3+ table configuration" do
      Table.create!(name: "GEN-D1", capacity: 2)
      Table.create!(name: "GEN-D2", capacity: 2)
      Table.create!(name: "GEN-D3", capacity: 2)

      configurations = ConfigurationGenerator.call

      assert configurations.all? { |c| c.table_count <= 2 }
    end

    # --- maximum_seatable_group_size (DEC-011, Phase 5B.12) ---

    test "maximum_seatable_group_size with no tables at all is 0" do
      assert_equal 0, ConfigurationGenerator.maximum_seatable_group_size
    end

    test "maximum_seatable_group_size is the largest single-table capacity when no adjacency beats it" do
      Table.create!(name: "MAX-1", capacity: 2)
      Table.create!(name: "MAX-2", capacity: 6)

      assert_equal 6, ConfigurationGenerator.maximum_seatable_group_size
    end

    test "maximum_seatable_group_size is the largest combined-pair capacity when it beats every single table" do
      t1 = Table.create!(name: "MAX-A1", capacity: 4)
      t2 = Table.create!(name: "MAX-A2", capacity: 4)
      TableAdjacency.pair!(t1, t2)
      Table.create!(name: "MAX-SOLO", capacity: 6)

      assert_equal 8, ConfigurationGenerator.maximum_seatable_group_size
    end

    test "maximum_seatable_group_size is unaffected by current occupancy — occupied tables still count" do
      t1 = Table.create!(name: "MAX-B1", capacity: 4)
      t2 = Table.create!(name: "MAX-B2", capacity: 4)
      TableAdjacency.pair!(t1, t2)
      claim_table!(t1)
      claim_table!(t2)

      # Both members of the pair are occupied — ConfigurationGenerator.call
      # (free tables only) would offer nothing for this pair — but the
      # structural maximum must still reflect it: occupancy is irrelevant to
      # whether a configuration could ever seat a group (this task's own
      # explicit "do NOT reject merely because tables are occupied").
      assert_equal 8, ConfigurationGenerator.maximum_seatable_group_size
      assert_equal 0, ConfigurationGenerator.call.count { |c| c.table_count == 2 }
    end
  end
end
