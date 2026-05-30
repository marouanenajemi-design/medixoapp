class Subscription < ApplicationRecord
  belongs_to :clinic

  STATUSES = %w[active past_due paused cancelled expired on_trial].freeze

  GRANTS_ACCESS = %w[active past_due on_trial].freeze

  validates :lemon_subscription_id, presence: true, uniqueness: true
  validates :plan_tier, presence: true
  validates :status, inclusion: { in: STATUSES }

  def grants_access?
    GRANTS_ACCESS.include?(status)
  end
end
