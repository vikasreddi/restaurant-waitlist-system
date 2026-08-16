require "test_helper"

class TableTest < ActiveSupport::TestCase
  test "valid capacity is accepted" do
    table = Table.new(name: "TX1", capacity: 4)
    assert table.valid?
  end

  test "invalid capacity is rejected" do
    table = Table.new(name: "TX2", capacity: 0)
    assert_not table.valid?
    assert_includes table.errors[:capacity], "must be greater than 0"
  end

  test "negative capacity is rejected" do
    table = Table.new(name: "TX3", capacity: -1)
    assert_not table.valid?
  end

  test "capacity > 0 is enforced at the database level, not just Rails validation" do
    table = Table.create!(name: "TX4", capacity: 4)

    # update_column bypasses Rails validations entirely but still has to pass
    # through the database — this proves the CHECK constraint, not the
    # validates: numericality rule above, is what actually protects this.
    assert_raises(ActiveRecord::StatementInvalid) do
      table.update_column(:capacity, 0)
    end
  end

  test "name must be unique" do
    Table.create!(name: "TX5", capacity: 2)
    dup = Table.new(name: "TX5", capacity: 4)

    assert_not dup.valid?
  end

  test "#free? is true when no claim exists" do
    table = Table.create!(name: "TX6", capacity: 2)
    assert table.free?
  end

  test "#free? is false while a non-released claim exists" do
    table = Table.create!(name: "TX7", capacity: 2)
    entry = QueueEntry.create!(group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid)
    assignment = SeatingAssignment.create!(queue_entry: entry)
    SeatingAssignmentTable.create!(seating_assignment: assignment, table: table)

    assert_not table.free?
  end
end
