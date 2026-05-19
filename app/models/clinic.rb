class Clinic < ApplicationRecord
  belongs_to :user

  has_many :doctors, dependent: :destroy
  has_many :patients, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :prescriptions, dependent: :destroy

  has_one_attached :logo


  validates :name, :address, :phone, presence: true

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

end
