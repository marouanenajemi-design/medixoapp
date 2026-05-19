class User < ApplicationRecord
  has_one :clinic, dependent: :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  scope :super_admins, -> { where(super_admin: true) }
  scope :regular_users, -> { where(super_admin: false) }
end
