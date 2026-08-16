require "test_helper"

class QueueEntryTest < ActiveSupport::TestCase
  def valid_attrs(overrides = {})
    { group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid }.merge(overrides)
  end

  test "valid group size is accepted" do
    entry = QueueEntry.new(valid_attrs)
    assert entry.valid?
  end

  test "invalid (zero) group size is rejected" do
    entry = QueueEntry.new(valid_attrs(group_size: 0))
    assert_not entry.valid?
  end

  test "negative group size is rejected" do
    entry = QueueEntry.new(valid_attrs(group_size: -3))
    assert_not entry.valid?
  end

  test "group_size > 0 is enforced at the database level" do
    entry = QueueEntry.create!(valid_attrs)

    assert_raises(ActiveRecord::StatementInvalid) do
      QueueEntry.connection.execute("UPDATE queue_entries SET group_size = 0 WHERE id = #{entry.id}")
    end
  end

  test "defaults to waiting status" do
    entry = QueueEntry.create!(valid_attrs)
    assert_equal "waiting", entry.status
  end

  test "an invalid status is rejected" do
    entry = QueueEntry.new(valid_attrs(status: "bogus"))
    assert_not entry.valid?
  end

  test "invalid status is rejected at the database level" do
    entry = QueueEntry.create!(valid_attrs)

    assert_raises(ActiveRecord::StatementInvalid) do
      QueueEntry.connection.execute("UPDATE queue_entries SET status = 'bogus' WHERE id = #{entry.id}")
    end
  end

  test "active_visit_token is generated automatically and is not blank" do
    entry = QueueEntry.create!(valid_attrs)
    assert entry.active_visit_token.present?
  end

  test "active_visit_token is not derived from phone number or id" do
    entry = QueueEntry.create!(valid_attrs(phone_number: "555-0199"))
    assert_not_includes entry.active_visit_token, "555-0199"
    assert_not_includes entry.active_visit_token, entry.id.to_s
  end

  test "two entries never receive the same active_visit_token" do
    a = QueueEntry.create!(valid_attrs)
    b = QueueEntry.create!(valid_attrs)
    assert_not_equal a.active_visit_token, b.active_visit_token
  end

  test "active_visit_token uniqueness is enforced at the database level" do
    a = QueueEntry.create!(valid_attrs)
    b = QueueEntry.create!(valid_attrs)

    assert_raises(ActiveRecord::StatementInvalid) do
      QueueEntry.connection.execute(
        "UPDATE queue_entries SET active_visit_token = '#{a.active_visit_token}' WHERE id = #{b.id}"
      )
    end
  end

  test "idempotency_key must be present (client-supplied, not auto-generated)" do
    entry = QueueEntry.new(valid_attrs(idempotency_key: nil))
    assert_not entry.valid?
  end

  test "a retried join with the same idempotency_key cannot create a second QueueEntry" do
    key = SecureRandom.uuid
    QueueEntry.create!(valid_attrs(idempotency_key: key))

    duplicate = QueueEntry.new(valid_attrs(idempotency_key: key))
    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
  end

  test "idempotency_key uniqueness is enforced at the database level, not just Rails validation" do
    key = SecureRandom.uuid
    QueueEntry.create!(valid_attrs(idempotency_key: key))

    assert_raises(ActiveRecord::RecordNotUnique) do
      QueueEntry.connection.execute(
        "INSERT INTO queue_entries (group_size, phone_number, idempotency_key, active_visit_token, " \
        "status, joined_at, created_at, updated_at) VALUES " \
        "(2, '555-0100', '#{key}', '#{SecureRandom.urlsafe_base64(32)}', 'waiting', now(), now(), now())"
      )
    end
  end

  test "phone number is required but is not the idempotency key" do
    entry = QueueEntry.new(valid_attrs(phone_number: nil))
    assert_not entry.valid?
  end

  test "joined_at is set automatically on creation" do
    entry = QueueEntry.create!(valid_attrs)
    assert entry.joined_at.present?
  end
end
