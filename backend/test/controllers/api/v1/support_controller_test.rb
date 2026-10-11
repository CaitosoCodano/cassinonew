require "test_helper"

class SupportControllerTest < ActionDispatch::IntegrationTest
  setup { ensure_roles! }

  test "guests can submit a support request" do
    post "/api/v1/support/requests", params: {
      subject: "Account question", message: "I need help with my account", category: "account"
    }, as: :json
    assert_response :created
    assert_nil json_body.dig("data", "user_id")
    assert_equal "open", json_body.dig("data", "status")
  end

  test "signed-in users can submit and list their own requests" do
    user = create_user
    login_as(user)

    post "/api/v1/support/requests", params: {
      subject: "Payment question", message: "When will deposits be available?", category: "payments"
    }, as: :json
    assert_response :created
    assert_equal user.id, json_body.dig("data", "user_id")

    get "/api/v1/support/requests"
    assert_response :success
    assert_equal 1, json_body["data"].size
  end

  test "multi-factor visibility: users never see other users' requests" do
    user = create_user
    other = create_user(email: "other@example.com")
    other.support_requests.create!(subject: "Secret", message: "Private", category: :complaint)

    login_as(user)
    get "/api/v1/support/requests"
    assert_empty json_body["data"]
  end
end