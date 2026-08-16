require "test_helper"

class TableAdjacencyTest < ActiveSupport::TestCase
  setup do
    @t1 = Table.create!(name: "AX1", capacity: 2)
    @t2 = Table.create!(name: "AX2", capacity: 2)
  end

  test "a valid adjacent pair can be created" do
    adjacency = TableAdjacency.pair!(@t1, @t2)
    assert adjacency.persisted?
  end

  test "pair! stores the canonical (lower id, higher id) order regardless of argument order" do
    adjacency = TableAdjacency.pair!(@t2, @t1) # deliberately reversed

    lower, higher = [@t1, @t2].sort_by(&:id)
    assert_equal lower.id, adjacency.table_id
    assert_equal higher.id, adjacency.adjacent_table_id
  end

  test "self adjacency is rejected at the Rails level" do
    adjacency = TableAdjacency.new(table: @t1, adjacent_table: @t1)
    assert_not adjacency.valid?
  end

  test "self adjacency is rejected at the database level" do
    assert_raises(ActiveRecord::StatementInvalid) do
      TableAdjacency.connection.execute(
        "INSERT INTO table_adjacencies (table_id, adjacent_table_id, created_at, updated_at) " \
        "VALUES (#{@t1.id}, #{@t1.id}, now(), now())"
      )
    end
  end

  test "a duplicate pair is rejected" do
    TableAdjacency.pair!(@t1, @t2)
    duplicate = TableAdjacency.new(table: @t1, adjacent_table: @t2)

    assert_not duplicate.valid?
  end

  test "a reversed duplicate pair does not create a second logical relationship" do
    TableAdjacency.pair!(@t1, @t2)

    assert_raises(ActiveRecord::RecordInvalid) do
      TableAdjacency.pair!(@t2, @t1) # same pair, reversed args -> same canonical row
    end
    assert_equal 1, TableAdjacency.count
  end

  test "#adjacent_tables on Table is symmetric regardless of storage direction" do
    TableAdjacency.pair!(@t1, @t2)

    assert_includes @t1.adjacent_tables, @t2
    assert_includes @t2.adjacent_tables, @t1
  end
end
