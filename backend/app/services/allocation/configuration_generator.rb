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
      new(tables: Table.order(:id).select(&:free?)).call
    end

    # DEC-011 (Phase 5B.12) — the maximum group size any valid configuration
    # (a single table, or an allowed adjacent pair) could EVER seat,
    # regardless of current availability. Deliberately computed over EVERY
    # table, not just free ones — occupancy is irrelevant to whether a
    # configuration structurally exists (this phase's own explicit
    # distinction: "do NOT reject a group merely because tables are
    # currently occupied"). Reuses the exact same single/combined
    # enumeration #call already performs for real allocation, just against a
    # different table scope — one source of truth for what a "valid
    # configuration" is, never a second algorithm.
    def self.maximum_seatable_group_size
      new(tables: Table.order(:id).to_a).call.map(&:capacity).max || 0
    end

    def initialize(tables:)
      @tables = tables
    end

    def call
      table_ids = @tables.map(&:id).to_set

      configurations = @tables.map { |table| TableConfiguration.single(table) }

      TableAdjacency.includes(:table, :adjacent_table).find_each do |adjacency|
        next unless table_ids.include?(adjacency.table_id) && table_ids.include?(adjacency.adjacent_table_id)

        configurations << TableConfiguration.combined(adjacency.table, adjacency.adjacent_table)
      end

      configurations
    end
  end
end
