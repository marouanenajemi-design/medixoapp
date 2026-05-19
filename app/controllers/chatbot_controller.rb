class ChatbotController < ApplicationController
  before_action :ensure_clinic!

  def index
    @query = params[:query].to_s.strip
    return if request.get?

    begin
      @chatbot_response = MedicineChatbotService.new(locale: I18n.locale).answer(query: @query)
    rescue StandardError => e
      Rails.logger.error("CHATBOT INDEX ERROR: #{e.class} - #{e.message}")
      @chatbot_response = {
        error: "Sorry, I could not find reliable information for this medicine right now."
      }
    end
  end

  def widget
    @query = params[:query].to_s.strip
    @chatbot_response = nil

    if @query.present?
      begin
        @chatbot_response = MedicineChatbotService.new(locale: I18n.locale).answer(query: @query)
      rescue StandardError => e
        Rails.logger.error("CHATBOT WIDGET ERROR: #{e.class} - #{e.message}")
        @chatbot_response = {
          error: "Sorry, I could not find reliable information for this medicine right now."
        }
      end
    end

    render layout: false
  end
end
