require "test_helper"

class MedicineChatbotServiceTest < ActiveSupport::TestCase
  test "returns structured informational fields for known medicine" do
    response = MedicineChatbotService.new(locale: :en).answer(query: "Tell me about ibuprofen")

    assert_equal "Ibuprofen", response[:medicine_name]
    assert response[:description].present?
    assert response[:common_uses].is_a?(Array)
    assert response[:general_warnings].is_a?(Array)
    assert response[:common_side_effects].is_a?(Array)
  end

  test "returns localized empty-query message" do
    response = MedicineChatbotService.new(locale: :fr).answer(query: "")

    assert_equal I18n.t("chatbot.messages.empty_query", locale: :fr), response[:error]
  end

  test "asks for medicine name when query has no recognizable medicine" do
    response = MedicineChatbotService.new(locale: :en).answer(query: "Can you diagnose me?")

    assert_equal I18n.t("chatbot.messages.ask_medicine_name", locale: :en), response[:error]
  end
end
