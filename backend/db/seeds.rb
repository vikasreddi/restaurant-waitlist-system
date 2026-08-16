# Deterministic restaurant table layout (DEC-001) — 40 tables, fixed seed data,
# no management screen. See documents/02-product-decisions/decision-log.md
# DEC-001 and documents/05-specifications/domain-model-proposal.md §12 for the
# full rationale behind this exact distribution and adjacency plan.
#
# Idempotent and safely rerunnable: uses find_or_create_by! throughout.

# 20 two-seat tables (T01-T20), 18 four-seat tables (T21-T38), 2 six-seat
# tables (T39-T40). Capacity determines compatibility — tables are NOT
# permanently dedicated to a group-size category (a smaller group may use a
# larger table when appropriate).
table_specs =
  (1..20).map { |n| [format("T%02d", n), 2] } +
  (21..38).map { |n| [format("T%02d", n), 4] } +
  (39..40).map { |n| [format("T%02d", n), 6] }

table_specs.each do |name, capacity|
  Table.find_or_create_by!(name: name) { |t| t.capacity = capacity }
end

puts "Seeded #{Table.count} tables." unless Rails.env.test?

# Deterministic adjacency, deliberately chosen to align with the allocation
# algorithm's needs, not arbitrary sequential pairing for its own sake:
# - 10 pairs among the 2-seat tables (T01<->T02 ... T19<->T20) -> 4-seat combos.
# - 9 pairs among the 4-seat tables (T21<->T22 ... T37<->T38) -> 8-seat combos,
#   the seed data's primary support for groups of 5-8.
# - T39/T40 (6-seat) are deliberately left non-adjacent to anything — no stated
#   requirement or realistic group size needs a >8-person automatic
#   configuration (see domain-model-proposal.md §12).
adjacency_pairs =
  (1..19).step(2).map { |n| [format("T%02d", n), format("T%02d", n + 1)] } +
  (21..37).step(2).map { |n| [format("T%02d", n), format("T%02d", n + 1)] }

adjacency_pairs.each do |name_a, name_b|
  table_a = Table.find_by!(name: name_a)
  table_b = Table.find_by!(name: name_b)

  next if TableAdjacency.exists?(table: table_a, adjacent_table: table_b) ||
    TableAdjacency.exists?(table: table_b, adjacent_table: table_a)

  TableAdjacency.pair!(table_a, table_b)
end

puts "Seeded #{TableAdjacency.count} adjacency pairs." unless Rails.env.test?
