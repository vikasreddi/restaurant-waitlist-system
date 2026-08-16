require "test_helper"

class StaffUserTest < ActiveSupport::TestCase
  test "a valid staff user can be created with a securely hashed password" do
    user = StaffUser.new(email: "staff@example.com", password: "stub-password")
    assert user.valid?
    user.save!
    assert user.password_digest.present?
    assert_not_equal "stub-password", user.password_digest
  end

  test "email must be unique" do
    StaffUser.create!(email: "dupe@example.com", password: "stub-password")
    dup = StaffUser.new(email: "dupe@example.com", password: "another-password")

    assert_not dup.valid?
  end

  test "email uniqueness is enforced at the database level" do
    StaffUser.create!(email: "dbcheck@example.com", password: "stub-password")

    assert_raises(ActiveRecord::RecordNotUnique) do
      StaffUser.connection.execute(
        "INSERT INTO staff_users (email, password_digest, created_at, updated_at) " \
        "VALUES ('dbcheck@example.com', 'x', now(), now())"
      )
    end
  end
end
