class WebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def lemonsqueezy
    body = request.raw_post
    signature = request.headers["X-Signature"]
    secret = ENV["LEMON_SQUEEZY_WEBHOOK_SECRET"]

    unless valid_signature?(body, signature, secret)
      head :unauthorized
      return
    end

    payload = JSON.parse(body)
    event_name = request.headers["X-Event-Name"] || payload.dig("meta", "event_name")

    case event_name
    when "subscription_created", "subscription_updated"
      activate_subscription(payload)
    when "subscription_cancelled", "subscription_expired"
      deactivate_subscription(payload)
    end

    head :ok
  end

  private

  def valid_signature?(body, signature, secret)
    return false if signature.blank? || secret.blank?

    digest = OpenSSL::HMAC.hexdigest("sha256", secret, body)
    ActiveSupport::SecurityUtils.secure_compare(digest, signature)
  end

  def activate_subscription(payload)
    attributes = payload.dig("data", "attributes") || {}
    email = attributes["user_email"]

    user = User.find_by(email: email)
    return unless user&.clinic

    user.clinic.update(
      subscribed: true,
      plan: "clinicflow-monthly",
      billing_customer_id: attributes["customer_id"]&.to_s,
      billing_subscription_id: payload.dig("data", "id")&.to_s
    )
  end

  def deactivate_subscription(payload)
    attributes = payload.dig("data", "attributes") || {}
    email = attributes["user_email"]

    user = User.find_by(email: email)
    return unless user&.clinic

    user.clinic.update(
      subscribed: false,
      billing_subscription_id: nil
    )
  end
end
