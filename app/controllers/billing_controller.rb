# Clinic-facing usage & billing screen: how many patient visits were recorded,
# the price per visit, and the resulting amount due. Everything is scoped to
# current_clinic, so one clinic can never see another clinic's usage.
class BillingController < ApplicationController
  before_action :ensure_clinic!

  def show
    @clinic  = current_clinic
    @summary = @clinic.billing_summary

    @recent_visits = @clinic.visits
                            .billable
                            .includes(:patient, :doctor)
                            .chronological
                            .limit(10)

    @visits_by_month = @clinic.visit_counts_by_month
  end
end
