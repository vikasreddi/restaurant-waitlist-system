module Allocation
  # OPEN-005 (documents/02-product-decisions/decision-log.md) — the exact
  # seating_code format/strength — is still explicitly unresolved as a
  # product decision. This phase's own governing prompt §15 permits the
  # smallest safe placeholder implementation in that case, on the condition
  # that the implementation decision is recorded (see
  # 06-ai-working-record/agent-decisions.md, Session 16) rather than silently
  # treated as OPEN-005 being closed. OPEN-005 itself remains open in
  # decision-log.md.
  #
  # Server-generated, not derived from the QueueEntry id, cryptographically
  # unpredictable (SecureRandom, not Kernel#rand — the same reasoning as
  # QueueEntry#active_visit_token: a guessable code could let someone falsely
  # trigger another guest's seating confirmation). 6 characters from a
  # 32-symbol alphabet that excludes visually-ambiguous characters (0/O,
  # 1/I/L) since staff read and type this by hand — ~1.07 billion possible
  # codes, comfortably collision-safe at restaurant scale while staying
  # short enough to read aloud.
  class SeatingCodeGenerator
    ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".chars.freeze
    LENGTH = 6

    def self.call
      Array.new(LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.size)] }.join
    end
  end
end
