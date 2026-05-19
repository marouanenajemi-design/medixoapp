require "test_helper"

class ChatbotControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @clinicless_user = users(:three)
  end

  test "authenticated owners with a clinic can view chatbot page" do
    sign_in_as(@owner)

    get chatbot_url

    assert_response :success
    assert_includes response.body, I18n.t("chatbot.title")
    assert_includes response.body, I18n.t("chatbot.disclaimer_title")
  end

  test "chatbot returns structured informational medicine response" do
    sign_in_as(@owner)

    post chatbot_url, params: { query: "What is ibuprofen used for?" }

    assert_response :success
    assert_includes response.body, I18n.t("chatbot.response.description")
    assert_includes response.body, I18n.t("chatbot.response.common_uses")
    assert_includes response.body, I18n.t("chatbot.response.general_warnings")
    assert_includes response.body, I18n.t("chatbot.response.common_side_effects")
    assert_includes response.body, I18n.t("chatbot.disclaimer_body")
  end

  test "clinicless users are redirected to clinic setup" do
    sign_in_as(@clinicless_user)

    get chatbot_url

    assert_redirected_to new_clinic_path(locale: current_locale)
  end
end
