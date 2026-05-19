require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get pricing" do
    get pages_pricing_url
    assert_response :success
  end
end
