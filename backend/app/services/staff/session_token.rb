module Staff
  # Resolves api-spec.md's "session established (mechanism TBD, e.g., cookie
  # or bearer token)" for POST /staff/login, per this phase's own explicit
  # instruction not to introduce JWT/session infrastructure unless required.
  #
  # A signed (not encrypted — the payload is only a staff_user_id, not
  # sensitive) bearer token via Rails' own ActiveSupport::MessageVerifier —
  # zero new dependencies, no new database table. Verified purely by
  # signature, without a DB round-trip for the signature check itself (a
  # cheap StaffUser existence check still happens in Staff::BaseController,
  # in case a staff user is ever removed later).
  #
  # Deliberately distinct in *mechanism* from Guest::QueueEntry#active_visit_
  # token (a random, DB-backed, unsigned value) — this phase's own governing
  # prompt §4 requires guest and staff authentication to stay separate; using
  # a different verification mechanism entirely, not merely a different
  # table, makes a guest token structurally unable to ever verify as a staff
  # token (it isn't a validly-signed payload at all), not just conventionally
  # unable to.
  #
  # Stub-strength (REQ-STAFF-001): no expiration, no revocation, no refresh
  # mechanism — a deliberate, documented simplification for a P0 stub, not
  # an oversight (this phase's own governing prompt §2 explicitly forbids
  # refresh-token infrastructure).
  class SessionToken
    PURPOSE = "staff_session"

    def self.verifier
      Rails.application.message_verifier(PURPOSE)
    end

    def self.generate(staff_user)
      verifier.generate({ staff_user_id: staff_user.id, issued_at: Time.current.to_i })
    end

    # Returns the staff_user_id if the token is validly signed, else nil.
    # Never raises on a tampered/garbage token — an invalid signature is an
    # ordinary "not authenticated" outcome, not an application error.
    def self.verify(token)
      return nil if token.blank?

      payload = verifier.verify(token)
      payload[:staff_user_id] || payload["staff_user_id"]
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end
  end
end
