class Admin::DashboardController < Admin::BaseController
  def index
    @total_users        = User.count
    @total_clinics      = Clinic.count
    @subscribed_clinics = Clinic.where(subscribed: true).count
    @trialing_clinics   = Clinic.where(subscribed: false).where("trial_ends_at > ?", Time.current).count
    @expired_clinics    = Clinic.where(subscribed: [false, nil])
                                .where("trial_ends_at IS NULL OR trial_ends_at <= ?", Time.current).count
    @total_doctors      = Doctor.count
    @total_patients     = Patient.count
    @total_appointments = Appointment.count

    @mrr               = compute_mrr
    @arr               = @mrr * 12
    @starter_count     = Clinic.where(plan_tier: "starter").count
    @pro_count         = Clinic.where(plan_tier: "pro").count
    @clinic_plus_count = Clinic.where(plan_tier: "clinic_plus").count

    @new_clinics_this_month = Clinic.where(created_at: Date.current.beginning_of_month..).count
    @new_clinics_last_month = Clinic.where(
      created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month
    ).count

    @revenue_by_month  = revenue_by_month_data
    @clinic_growth     = clinic_growth_data
    @plan_distribution = plan_distribution_data
    @recent_activity   = recent_activity_data

    @recent_users   = User.includes(:clinic).order(created_at: :desc).limit(6)
    @recent_clinics = Clinic.includes(:user).order(created_at: :desc).limit(6)
  end

  private

  def compute_mrr
    Clinic.where(subscribed: true).sum do |clinic|
      PlanGating::PLANS[clinic.plan_tier.to_s]&.dig(:price) || 0
    end
  end

  def revenue_by_month_data
    (5).downto(0).map do |months_ago|
      period_end = months_ago.months.ago.end_of_month
      subscribed = Clinic.where(subscribed: true).where("created_at <= ?", period_end)
      revenue    = subscribed.sum { |c| PlanGating::PLANS[c.plan_tier.to_s]&.dig(:price) || 0 }
      { month: period_end.strftime("%b %Y"), revenue: revenue }
    end
  end

  def clinic_growth_data
    (5).downto(0).map do |months_ago|
      month_start = months_ago.months.ago.beginning_of_month
      month_end   = months_ago.months.ago.end_of_month
      count = Clinic.where(created_at: month_start..month_end).count
      { month: month_start.strftime("%b %Y"), count: count }
    end
  end

  def plan_distribution_data
    PlanGating::PLANS.map do |tier, config|
      { name: config[:name], count: Clinic.where(plan_tier: tier).count, tier: tier }
    end
  end

  def recent_activity_data
    Clinic.includes(:user).order(updated_at: :desc).limit(12).map do |clinic|
      if clinic.subscribed?
        { type: "upgrade", clinic: clinic, label: "Subscribed — #{clinic.plan_name}", time: clinic.updated_at }
      elsif clinic.trialing?
        { type: "trial", clinic: clinic, label: "On trial", time: clinic.created_at }
      elsif clinic.trial_ends_at.present? && clinic.trial_ends_at.past?
        { type: "expired", clinic: clinic, label: "Trial expired", time: clinic.trial_ends_at }
      else
        { type: "new", clinic: clinic, label: "New registration", time: clinic.created_at }
      end
    end
  end
end
