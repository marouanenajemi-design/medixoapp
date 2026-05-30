class Conversation < ApplicationRecord
  belongs_to :clinic
  has_many :chat_messages, dependent: :destroy

  validates :clinic, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def display_title
    title.presence || "Conversation ##{id}"
  end
end
