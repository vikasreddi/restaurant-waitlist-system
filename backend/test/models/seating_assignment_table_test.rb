require "test_helper"

class SeatingAssignmentTableTest < ActiveSupport::TestCase
  def new_entry
    QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
  end

  setup do
    @table = Table.create!(name: "SX1", capacity: 4)
    @assignment = SeatingAssignment.create!(queue_entry: new_entry)
  end

  test "a table can be claimed by an assignment" do
    claim = SeatingAssignmentTable.create!(seating_assignment: @assignment, table: @table)
    assert claim.persisted?
    assert_nil claim.released_at
  end

  test "requires a valid table and assignment" do
    claim = SeatingAssignmentTable.new
    assert_not claim.valid?
  end

  # --- The core invariant: one group per table (INV-001/002/003) ---

  test "the same table cannot be claimed by two current assignments (Rails-level)" do
    SeatingAssignmentTable.create!(seating_assignment: @assignment, table: @table)

    other_assignment = SeatingAssignment.create!(queue_entry: new_entry)
    second_claim = SeatingAssignmentTable.new(seating_assignment: other_assignment, table: @table)

    assert_not second_claim.valid?
  end

  test "the same table cannot be claimed by two current assignments — enforced at the database level" do
    SeatingAssignmentTable.create!(seating_assignment: @assignment, table: @table)
    other_assignment = SeatingAssignment.create!(queue_entry: new_entry)

    # Bypass the Rails-level validation entirely to prove the database itself
    # (the UNIQUE(table_id) WHERE released_at IS NULL partial index) is what
    # actually protects this invariant — not just application code.
    assert_raises(ActiveRecord::RecordNotUnique) do
      SeatingAssignmentTable.connection.execute(
        "INSERT INTO seating_assignment_tables (seating_assignment_id, table_id, created_at, updated_at) " \
        "VALUES (#{other_assignment.id}, #{@table.id}, now(), now())"
      )
    end
  end

  test "a released table can be claimed again" do
    first_claim = SeatingAssignmentTable.create!(seating_assignment: @assignment, table: @table)
    first_claim.update!(released_at: Time.current)

    other_assignment = SeatingAssignment.create!(queue_entry: new_entry)
    second_claim = SeatingAssignmentTable.new(seating_assignment: other_assignment, table: @table)

    assert second_claim.valid?
    second_claim.save!
    assert @table.reload.free? == false # now claimed by the new assignment
  end

  test "released rows are never deleted — historical assignments remain queryable" do
    claim = SeatingAssignmentTable.create!(seating_assignment: @assignment, table: @table)
    claim.update!(released_at: Time.current)

    assert SeatingAssignmentTable.exists?(claim.id)
    assert_equal 1, SeatingAssignmentTable.where(table: @table).count
  end

  # --- Combined (2-table) assignments ---

  test "one assignment can claim two adjacent tables" do
    table_two = Table.create!(name: "SX2", capacity: 4)

    SeatingAssignmentTable.create!(seating_assignment: @assignment, table: @table)
    SeatingAssignmentTable.create!(seating_assignment: @assignment, table: table_two)

    assert_equal 2, @assignment.seating_assignment_tables.count
    assert_equal [@table, table_two].sort_by(&:id), @assignment.tables.sort_by(&:id)
  end

  test "an assignment cannot claim a third table (DEC-002, max 2 tables)" do
    table_two = Table.create!(name: "SX3", capacity: 4)
    table_three = Table.create!(name: "SX4", capacity: 4)

    SeatingAssignmentTable.create!(seating_assignment: @assignment, table: @table)
    SeatingAssignmentTable.create!(seating_assignment: @assignment, table: table_two)
    third_claim = SeatingAssignmentTable.new(seating_assignment: @assignment, table: table_three)

    assert_not third_claim.valid?
  end

  test "a combined (2-table) claim is genuinely atomic: if one insert fails, neither table ends up claimed" do
    table_two = Table.create!(name: "SX5", capacity: 4)
    # Pre-claim table_two via a different assignment so the second insert below fails.
    blocking_assignment = SeatingAssignment.create!(queue_entry: new_entry)
    SeatingAssignmentTable.create!(seating_assignment: blocking_assignment, table: table_two)

    assert_raises(ActiveRecord::RecordInvalid) do
      ActiveRecord::Base.transaction do
        SeatingAssignmentTable.create!(seating_assignment: @assignment, table: @table)
        SeatingAssignmentTable.create!(seating_assignment: @assignment, table: table_two) # fails: already claimed
      end
    end

    # Neither claim should exist for @assignment — the whole transaction rolled back.
    assert_equal 0, @assignment.seating_assignment_tables.count
    assert @table.reload.free?
  end
end
