require "test_helper"

class AssistantsControllerTest < ActionDispatch::IntegrationTest
  test "should get interact" do
    get assistants_interact_url
    assert_response :success
  end
end
