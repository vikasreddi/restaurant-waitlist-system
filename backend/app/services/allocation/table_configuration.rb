module Allocation
  # Immutable description of a candidate table configuration — either one
  # free table or a valid free adjacent pair (never 3+, DEC-002/INV-012).
  # Carries only what the later transactional allocation phase will need to
  # know what was selected (allocation-algorithm.md §4) — deliberately not
  # coupled to ActiveRecord beyond the table ids themselves, so the pure
  # DecisionEngine never needs to touch a Table row.
  TableConfiguration = Struct.new(:table_ids, :capacity, :table_count) do
    def self.single(table)
      new([table.id], table.capacity, 1)
    end

    # table_ids stored in ascending order regardless of argument order, so
    # [3, 4] and [4, 3] are never two different representations of the same
    # pair — mirrors TableAdjacency's own canonical (table_id < adjacent_
    # table_id) storage, which is also what guarantees the caller (see
    # Allocation::ConfigurationGenerator) never has a reverse duplicate to
    # begin with.
    def self.combined(table_a, table_b)
      new([table_a.id, table_b.id].sort, table_a.capacity + table_b.capacity, 2)
    end
  end
end
