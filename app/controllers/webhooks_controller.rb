class WebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  # Maps LemonSqueezy variant IDs to internal plan_tier strings.
  # Update these if you add new products/variants in LemonSqueezy.
  VARIANT_PLAN_MAP = {
    "1724184" => "starter",
    "1724194" => "pro",
    "1724195" => "clinic_plus"
  }.freeze

  # Subscription statuses that keep clinic access active.
  # - active     : normal paid subscription
  # - past_due   : payment failed but in grace period — keep access
  # - on_trial   : LemonSqueezy-managed trial
  ACTIVE_STATUSES = %w[active past_due on_trial].freeze

  def lemonsqueezy
    raw_body  = request.raw_post
    signature = request.headers["X-Signature"].to_s

    unless valid_signature?(raw_body, signature)
      Rails.logger.warn("[Webhook] Invalid LemonSqueezy signature — rejected")
      head :unauthorized and return
    end

    payload    = JSON.parse(raw_body)
    event_name = request.headers["X-Event-Name"].presence ||
                 payload.dig("meta", "event_name").to_s

    Rails.logger.info("[Webhook] LemonSqueezy event: #{event_name}")

    case event_name
    when "subscription_created"                then handle_subscription_created(payload)
    when "subscription_updated"                then handle_subscription_updated(payload)
    when "subscription_cancelled"              then handle_subscription_cancelled(payload)
    when "subscription_resumed"                then handle_subscription_resumed(payload)
    when "subscription_expired"                then handle_subscription_expired(payload)
    else
      Rails.logger.info("[Webhook] Unhandled event: #{event_name} — ignored")
    end

    head :ok
  rescue JSON::ParserError => e
    Rails.logger.error("[Webhook] JSON parse error: #{e.message}")
    head :bad_request
  rescue => e
    Rails.logger.error("[Webhook] Unexpected error for #{event_name.inspect}: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    head :internal_server_error
  end

  private

  # ── Signature verification ───────────────────────────────────────────────────

  def valid_signature?(body, signature)
    secret = ENV["LEMON_SQUEEZY_WEBHOOK_SECRET"]
    return false if secret.blank? || signature.blank?

    expected = OpenSSL::HMAC.hexdigest("sha256", secret, body)
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end

  # ── Event handlers ───────────────────────────────────────────────────────────

  # Fired when a new subscription is created (user completes checkout).
  # custom_data.clinic_id is the primary lookup; falls back to user email.
  def handle_subscription_created(payload)
    attrs   = payload.dig("data", "attributes") || {}
    clinic  = resolve_clinic(payload)

    unless clinic
      Rails.logger.warn("[Webhook] subscription_created: could not resolve clinic — payload: #{attrs.slice('user_email', 'customer_id').inspect}")
      return
    end

    plan_tier = variant_to_plan(attrs["variant_id"])
    sub_id    = payload.dig("data", "id").to_s

    subscription = clinic.subscriptions.find_or_initialize_by(lemon_subscription_id: sub_id)
    subscription.assign_attributes(
      lemon_customer_id:   attrs["customer_id"]&.to_s,
      lemon_order_id:      attrs["order_id"]&.to_s,
      lemon_product_id:    attrs["product_id"]&.to_s,
      lemon_variant_id:    attrs["variant_id"]&.to_s,
      status:              normalize_status(attrs["status"]),
      plan_tier:           plan_tier,
      renews_at:           parse_ls_time(attrs["renews_at"]),
      ends_at:             parse_ls_time(attrs["ends_at"]),
      trial_ends_at:       parse_ls_time(attrs["trial_ends_at"])
    )
    subscription.save!

    clinic.update!(
      subscribed:               true,
      plan_tier:                plan_tier,
      billing_customer_id:      attrs["customer_id"]&.to_s,
      billing_subscription_id:  sub_id
    )

    Rails.logger.info("[Webhook] subscription_created — clinic=#{clinic.id} plan=#{plan_tier} sub=#{sub_id}")
  end

  # Fired on any subscription change: plan swap, billing cycle, payment method, etc.
  def handle_subscription_updated(payload)
    attrs        = payload.dig("data", "attributes") || {}
    sub_id       = payload.dig("data", "id").to_s
    subscription = Subscription.find_by(lemon_subscription_id: sub_id)

    unless subscription
      # May arrive before subscription_created in rare cases — treat as created.
      handle_subscription_created(payload)
      return
    end

    plan_tier = variant_to_plan(attrs["variant_id"]) || subscription.plan_tier
    status    = normalize_status(attrs["status"])

    subscription.update!(
      lemon_variant_id:  attrs["variant_id"]&.to_s,
      status:            status,
      plan_tier:         plan_tier,
      renews_at:         parse_ls_time(attrs["renews_at"]),
      ends_at:           parse_ls_time(attrs["ends_at"]),
      trial_ends_at:     parse_ls_time(attrs["trial_ends_at"])
    )

    subscribed = ACTIVE_STATUSES.include?(status)
    subscription.clinic.update!(
      subscribed: subscribed,
      plan_tier:  plan_tier
    )

    Rails.logger.info("[Webhook] subscription_updated — clinic=#{subscription.clinic_id} plan=#{plan_tier} status=#{status}")
  end

  # Fired when user cancels. Access continues until ends_at (period already paid).
  # We keep subscribed: true here and flip it on subscription_expired.
  def handle_subscription_cancelled(payload)
    attrs        = payload.dig("data", "attributes") || {}
    sub_id       = payload.dig("data", "id").to_s
    subscription = Subscription.find_by(lemon_subscription_id: sub_id)

    unless subscription
      Rails.logger.warn("[Webhook] subscription_cancelled: subscription #{sub_id} not found")
      return
    end

    subscription.update!(
      status:   "cancelled",
      ends_at:  parse_ls_time(attrs["ends_at"])
    )

    # Keep clinic subscribed — they paid through the current period.
    # subscription_expired fires when access should actually end.
    Rails.logger.info("[Webhook] subscription_cancelled — clinic=#{subscription.clinic_id} ends_at=#{subscription.ends_at}")
  end

  # Fired when a cancelled subscription is reactivated before its end date.
  def handle_subscription_resumed(payload)
    attrs        = payload.dig("data", "attributes") || {}
    sub_id       = payload.dig("data", "id").to_s
    subscription = Subscription.find_by(lemon_subscription_id: sub_id)

    unless subscription
      Rails.logger.warn("[Webhook] subscription_resumed: subscription #{sub_id} not found")
      return
    end

    plan_tier = variant_to_plan(attrs["variant_id"]) || subscription.plan_tier

    subscription.update!(
      status:    "active",
      plan_tier: plan_tier,
      ends_at:   parse_ls_time(attrs["ends_at"]),
      renews_at: parse_ls_time(attrs["renews_at"])
    )

    subscription.clinic.update!(
      subscribed: true,
      plan_tier:  plan_tier
    )

    Rails.logger.info("[Webhook] subscription_resumed — clinic=#{subscription.clinic_id} plan=#{plan_tier}")
  end

  # Fired when the subscription's period has fully ended (post-cancellation).
  def handle_subscription_expired(payload)
    sub_id       = payload.dig("data", "id").to_s
    subscription = Subscription.find_by(lemon_subscription_id: sub_id)

    unless subscription
      Rails.logger.warn("[Webhook] subscription_expired: subscription #{sub_id} not found")
      return
    end

    subscription.update!(status: "expired")
    subscription.clinic.update!(subscribed: false)

    Rails.logger.info("[Webhook] subscription_expired — clinic=#{subscription.clinic_id} — access revoked")
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  # Find clinic by (1) custom_data.clinic_id from checkout URL, (2) user email.
  def resolve_clinic(payload)
    clinic_id = payload.dig("meta", "custom_data", "clinic_id").to_s.presence
    if clinic_id
      clinic = Clinic.find_by(id: clinic_id)
      return clinic if clinic
      Rails.logger.warn("[Webhook] resolve_clinic: custom_data.clinic_id=#{clinic_id} not found — falling back to email")
    end

    email = payload.dig("data", "attributes", "user_email").to_s.strip.downcase
    User.find_by(email: email)&.clinic
  end

  def variant_to_plan(variant_id)
    VARIANT_PLAN_MAP[variant_id.to_s]
  end

  def normalize_status(raw_status)
    s = raw_status.to_s.downcase
    Subscription::STATUSES.include?(s) ? s : "active"
  end

  def parse_ls_time(value)
    return nil if value.blank?
    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
