class ChatMessage < ApplicationRecord
  belongs_to :conversation

  ROLES = %w[user assistant].freeze

  validates :role,    presence: true, inclusion: { in: ROLES }
  validates :content, presence: true

  scope :chronological, -> { order(:created_at) }

  def user?
    role == "user"
  end

  def assistant?
    role == "assistant"
  end

  # response_data is a jsonb column — Rails returns a Hash with string keys.
  # This accessor normalises to indifferent access so views can use either.
  def parsed_response
    return nil if response_data.blank?

    response_data.with_indifferent_access
  end

  def error_message?
    assistant? && response_data.blank? && content.present?
  end
end
