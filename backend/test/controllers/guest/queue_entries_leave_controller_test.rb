require "test_helper"

module Guest
  class QueueEntriesLeaveControllerTest < ActionDispatch::IntegrationTest
    def post_join(overrides = {})
      body = { group_size: 2, phone_number: "555-0100", idempotency_key: SecureRandom.uuid }.merge(overrides)
      post "/guest/queue-entries", params: body, as: :json
      JSON.parse(response.body)
    end

    def post_leave(token)
      headers = token ? { "Authorization" => "Bearer #{token}" } : {}
      post "/guest/queue-entries/current/leave", headers: headers, as: :json
    end

    test "a waiting guest can leave via the real HTTP endpoint" do
      joined = post_join

      post_leave(joined["active_visit_token"])

      assert_response :ok
      assert_equal "left", JSON.parse(response.body)["status"]
    end

    test "a ready guest can leave, and the guest current-status endpoint reflects it afterward" do
      Table.create!(name: "CTL-1", capacity: 2)
      joined = post_join
      assert_equal "ready", joined["status"]

      post_leave(joined["active_visit_token"])
      assert_response :ok
      assert_equal "left", JSON.parse(response.body)["status"]

      get "/guest/queue-entries/current", headers: { "Authorization" => "Bearer #{joined['active_visit_token']}" }
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal "left", body["status"]
      assert_not body.key?("entry_id")
      assert_not body.key?("position")
    end

    test "missing token returns 404" do
      post_leave(nil)
      assert_response :not_found
      assert_equal "not_found", JSON.parse(response.body)["error"]["type"]
    end

    test "an invalid token returns 404" do
      post_leave(SecureRandom.urlsafe_base64(32))
      assert_response :not_found
    end

    test "repeated leave via HTTP is idempotent and returns 200 both times" do
      joined = post_join
      post_leave(joined["active_visit_token"])
      assert_response :ok

      post_leave(joined["active_visit_token"])

      assert_response :ok
      assert_equal "left", JSON.parse(response.body)["status"]
    end

    test "guest A cannot leave guest B's visit" do
      joined_a = post_join(phone_number: "555-1001", idempotency_key: SecureRandom.uuid)
      joined_b = post_join(phone_number: "555-1002", idempotency_key: SecureRandom.uuid)

      post_leave(joined_a["active_visit_token"])

      get "/guest/queue-entries/current", headers: { "Authorization" => "Bearer #{joined_b['active_visit_token']}" }
      body = JSON.parse(response.body)
      assert_equal "waiting", body["status"]
    end

    test "leaving a ready guest lets an eligible waiting guest be allocated the freed table" do
      Table.create!(name: "CTL-2", capacity: 2)
      leaving = post_join(phone_number: "555-2001", idempotency_key: SecureRandom.uuid)
      assert_equal "ready", leaving["status"]

      waiting_guest = post_join(phone_number: "555-2002", idempotency_key: SecureRandom.uuid)
      assert_equal "waiting", waiting_guest["status"]

      post_leave(leaving["active_visit_token"])
      assert_response :ok

      get "/guest/queue-entries/current", headers: { "Authorization" => "Bearer #{waiting_guest['active_visit_token']}" }
      assert_equal "ready", JSON.parse(response.body)["status"]
    end
  end
end
