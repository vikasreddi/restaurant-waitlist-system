require "test_helper"

# Exercises the actual db/seeds.rb script (via Rails' own seed-loading
# mechanism, not a re-implementation of its logic) against a clean slate, and
# verifies the exact deterministic distribution DEC-001 requires.
class SeedDataTest < ActiveSupport::TestCase
  setup do
    Table.delete_all
    TableAdjacency.delete_all
    Rails.application.load_seed
  end

  test "exactly 40 tables are seeded" do
    assert_equal 40, Table.count
  end

  test "capacity distribution matches DEC-001 exactly" do
    assert_equal 20, Table.where(capacity: 2).count
    assert_equal 18, Table.where(capacity: 4).count
    assert_equal 2, Table.where(capacity: 6).count
  end

  test "table names are deterministic (T01..T40)" do
    expected = (1..40).map { |n| format("T%02d", n) }
    assert_equal expected.sort, Table.pluck(:name).sort
  end

  test "exactly 19 adjacency pairs are seeded" do
    assert_equal 19, TableAdjacency.count
  end

  test "the two 6-seat tables (T39, T40) are not adjacent to anything" do
    t39 = Table.find_by!(name: "T39")
    t40 = Table.find_by!(name: "T40")

    assert_empty t39.adjacent_tables
    assert_empty t40.adjacent_tables
  end

  test "T01 is adjacent to T02, and only T02" do
    t01 = Table.find_by!(name: "T01")
    assert_equal ["T02"], t01.adjacent_tables.pluck(:name)
  end

  test "T21 (4-seat) is adjacent to T22, forming an 8-capacity combined configuration" do
    t21 = Table.find_by!(name: "T21")
    t22 = Table.find_by!(name: "T22")

    assert_includes t21.adjacent_tables, t22
    assert_equal 8, t21.capacity + t22.capacity
  end

  test "seeding twice is idempotent (safely rerunnable)" do
    assert_no_difference -> { Table.count } do
      Rails.application.load_seed
    end
    assert_no_difference -> { TableAdjacency.count } do
      Rails.application.load_seed
    end
  end
end
