module PlanGating
  extend ActiveSupport::Concern

  PLANS = {
    "starter" => {
      name:          "Starter",
      price:         29,
      badge_color:   "#64748b",
      doctor_limit:  2,
      patient_limit: 100,
      features: %w[
        dashboard doctors patients appointments
        prescriptions calendar chatbot
      ]
    },
    "pro" => {
      name:          "Pro",
      price:         69,
      badge_color:   "#14b8a6",
      doctor_limit:  10,
      patient_limit: 1_000,
      features: %w[
        dashboard doctors patients appointments
        prescriptions calendar chatbot analytics
      ]
    },
    "clinic_plus" => {
      name:          "Clinic+",
      price:         149,
      badge_color:   "#0f172a",
      doctor_limit:  nil,
      patient_limit: nil,
      features: %w[
        dashboard doctors patients appointments
        prescriptions calendar chatbot analytics
        white_label api priority_support
      ]
    }
  }.freeze

  def plan_config
    PLANS[plan_tier.to_s] || PLANS["starter"]
  end

  def plan_name
    plan_config[:name]
  end

  def plan_badge_color
    plan_config[:badge_color]
  end

  def plan_allows?(feature)
    plan_config[:features].include?(feature.to_s)
  end

  def within_limit?(resource)
    limit = case resource.to_sym
            when :doctors  then plan_config[:doctor_limit]
            when :patients then plan_config[:patient_limit]
            else return true
            end
    return true if limit.nil?

    current = case resource.to_sym
              when :doctors  then doctors.count
              when :patients then patients.count
              end
    current < limit
  end

  def doctor_limit
    plan_config[:doctor_limit]
  end

  def patient_limit
    plan_config[:patient_limit]
  end

  def plan_usage
    {
      doctors:  { current: doctors.count,      limit: doctor_limit  },
      patients: { current: patients.count,     limit: patient_limit },
      appointments: { current: appointments.count, limit: nil }
    }
  end

  def plan_usage_percent(resource)
    usage = plan_usage[resource]
    return nil if usage[:limit].nil?
    return 0   if usage[:current].zero?
    [(usage[:current].to_f / usage[:limit] * 100).round, 100].min
  end
end
