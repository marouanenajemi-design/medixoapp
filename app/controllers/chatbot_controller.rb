class ChatbotController < ApplicationController
  before_action :ensure_clinic!
  before_action :load_conversation, only: [:index, :ask, :clear]

  # GET /chatbot
  def index
    @messages = @conversation.chat_messages.chronological.last(20)
  end

  # POST /chatbot/ask  (Turbo Stream preferred, HTML fallback)
  def ask
    @query = params[:query].to_s.strip

    if @query.blank?
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.append(
            "chat-thread",
            partial: "chatbot/error_bubble",
            locals:  { message: t("chatbot.messages.empty_query") }
          )
        }
        format.html { redirect_to chatbot_path }
      end
      return
    end

    is_first = @conversation.chat_messages.empty?

    # Persist user turn
    user_msg = @conversation.chat_messages.create!(role: "user", content: @query)

    # Auto-title the conversation from the first query
    @conversation.update!(title: @query.truncate(60)) if is_first

    # Call AI service (uses Rails.cache internally)
    response_hash = MedicineChatbotService.new(locale: I18n.locale).answer(query: @query)

    # Persist assistant turn
    ai_msg = build_assistant_message(@conversation, response_hash)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.append("chat-thread",
            partial: "chatbot/message", locals: { message: user_msg }),
          turbo_stream.append("chat-thread",
            partial: "chatbot/message", locals: { message: ai_msg })
        ]
      }
      format.html { redirect_to chatbot_path }
    end
  rescue StandardError => e
    Rails.logger.error("[ChatbotController#ask] #{e.class}: #{e.message}")
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.append(
          "chat-thread",
          partial: "chatbot/error_bubble",
          locals:  { message: t("chatbot.messages.service_unavailable") }
        )
      }
      format.html { redirect_to chatbot_path }
    end
  end

  # POST /chatbot/new  — starts a fresh conversation
  def new_chat
    session.delete(:chatbot_conversation_id)
    redirect_to chatbot_path
  end

  # DELETE /chatbot/clear  — wipes messages but keeps the conversation row
  def clear
    @conversation.chat_messages.destroy_all
    @conversation.update!(title: nil)
    redirect_to chatbot_path
  end

  # GET /chatbot/widget  — standalone page embedded as iframe
  def widget
    @conversation = find_or_create_conversation
    @messages     = @conversation.chat_messages.chronological.last(20)
  end

  # POST /chatbot/widget/ask
  def widget_ask
    @conversation = find_or_create_conversation
    @query        = params[:query].to_s.strip

    if @query.blank?
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.append(
            "widget-thread",
            partial: "chatbot/widget_error_bubble",
            locals:  { message: t("chatbot.messages.empty_query") }
          )
        }
        format.html { redirect_to chatbot_widget_path }
      end
      return
    end

    is_first = @conversation.chat_messages.empty?
    user_msg = @conversation.chat_messages.create!(role: "user", content: @query)
    @conversation.update!(title: @query.truncate(60)) if is_first

    response_hash = MedicineChatbotService.new(locale: I18n.locale).answer(query: @query)
    ai_msg        = build_assistant_message(@conversation, response_hash)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.append("widget-thread",
            partial: "chatbot/widget_message", locals: { message: user_msg }),
          turbo_stream.append("widget-thread",
            partial: "chatbot/widget_message", locals: { message: ai_msg })
        ]
      }
      format.html { redirect_to chatbot_widget_path }
    end
  rescue StandardError => e
    Rails.logger.error("[ChatbotController#widget_ask] #{e.class}: #{e.message}")
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.append(
          "widget-thread",
          partial: "chatbot/widget_error_bubble",
          locals:  { message: t("chatbot.messages.service_unavailable") }
        )
      }
      format.html { redirect_to chatbot_widget_path }
    end
  end

  private

  def load_conversation
    @conversation = find_or_create_conversation
  end

  # Finds the current clinic's active conversation from the session,
  # or creates a new one. The clinic scope prevents cross-tenant access.
  def find_or_create_conversation
    conv = current_clinic.conversations.find_by(id: session[:chatbot_conversation_id])
    unless conv
      conv = current_clinic.conversations.create!
      session[:chatbot_conversation_id] = conv.id
    end
    conv
  end

  # Stores the AI service response as a ChatMessage row.
  # Error responses are stored as plain text with no response_data.
  def build_assistant_message(conversation, response_hash)
    if response_hash[:error].present?
      conversation.chat_messages.create!(
        role:    "assistant",
        content: response_hash[:error]
      )
    else
      conversation.chat_messages.create!(
        role:          "assistant",
        content:       response_hash[:description].to_s.presence || response_hash[:medicine_name].to_s,
        response_data: response_hash.except(:error)
      )
    end
  end
end
