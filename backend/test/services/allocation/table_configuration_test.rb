require "test_helper"

module Allocation
  class TableConfigurationTest < ActiveSupport::TestCase
    FakeTable = Struct.new(:id, :capacity)

    test "single builds a table_count-1 configuration from one table" do
      table = FakeTable.new(7, 4)
      configuration = TableConfiguration.single(table)

      assert_equal [7], configuration.table_ids
      assert_equal 4, configuration.capacity
      assert_equal 1, configuration.table_count
    end

    test "combined sums capacity and reports table_count 2" do
      a = FakeTable.new(3, 4)
      b = FakeTable.new(4, 4)
      configuration = TableConfiguration.combined(a, b)

      assert_equal 8, configuration.capacity
      assert_equal 2, configuration.table_count
    end

    test "combined table_ids are always canonically ascending, regardless of argument order" do
      a = FakeTable.new(4, 4)
      b = FakeTable.new(3, 4)

      forward = TableConfiguration.combined(a, b)
      reverse = TableConfiguration.combined(b, a)

      assert_equal [3, 4], forward.table_ids
      assert_equal [3, 4], reverse.table_ids
    end
  end
end
