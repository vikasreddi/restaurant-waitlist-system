module Allocation
  # The one piece of the allocation-decision path that reads the database —
  # deliberately kept separate from DecisionEngine, which must stay pure
  # (allocation-algorithm.md §2/§4; this phase's own governing prompt §24/
  # §28: "the important boundary is pure decision != database allocation
  # transaction"). Turns live Table/TableAdjacency state into the plain
  # TableConfiguration objects DecisionEngine actually consumes.
  #
  # TableAdjacency is already stored canonically (table_id < adjacent_
  # table_id, DB check constraint, Phase 5B.2) — so this never needs its own
  # duplicate-pair deduplication logic; there is exactly one row per valid
  # pair by construction, and it is only ever read here, never written.
  class ConfigurationGenerator
    def self.call
      new.call
    end

    def call
      free_tables = Table.order(:id).select(&:free?)
      free_table_ids = free_tables.map(&:id).to_set

      configurations = free_tables.map { |table| TableConfiguration.single(table) }

      TableAdjacency.includes(:table, :adjacent_table).find_each do |adjacency|
        next unless free_table_ids.include?(adjacency.table_id) && free_table_ids.include?(adjacency.adjacent_table_id)

        configurations << TableConfiguration.combined(adjacency.table, adjacency.adjacent_table)
      end

      configurations
    end
  end
end
