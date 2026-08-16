require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "GET /health returns 200 with status ok" do
    get "/health"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "ok", body["status"]
  end
end
