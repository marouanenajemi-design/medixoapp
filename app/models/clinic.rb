class Clinic < ApplicationRecord
  include PlanGating

  belongs_to :user
  has_many :subscriptions,   dependent: :destroy
  has_many :conversations,   dependent: :destroy
  has_many :doctors,         dependent: :destroy
  has_many :patients,       dependent: :destroy
  has_many :appointments,   dependent: :destroy
  has_many :prescriptions,  dependent: :destroy

  has_one_attached :logo

  validates :name, :address, :phone, presence: true
  validates :slug, presence: true, uniqueness: { case_sensitive: false }

  before_validation :generate_slug, on: :create

  def trialing?
    !subscribed? && trial_ends_at.present? && trial_ends_at.future?
  end

  def access_active?
    subscribed? || trialing?
  end

  def trial_days_left
    return 0 unless trial_ends_at.present?
    days = (trial_ends_at.to_date - Date.current).to_i
    days.positive? ? days : 0
  end

  def online_bookings
    appointments.where(source: "online")
  end

  def pending_online_bookings_count
    appointments.where(source: "online", status: "pending").count
  end

  private

  def generate_slug
    return if slug.present?
    base      = name.to_s.parameterize.presence || "clinic"
    candidate = base
    n = 1
    while Clinic.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{n}"
      n += 1
    end
    self.slug = candidate
  end
end
