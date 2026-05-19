module AuthenticatedIntegrationHelpers
  def sign_in_as(user)
    sign_in(user)
    user
  end

  def current_locale
    I18n.default_locale
  end
end
