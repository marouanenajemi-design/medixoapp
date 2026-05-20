class BookingsController < ApplicationController
  layout "booking"
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :check_clinic_access

  before_action :find_clinic
  before_action :check_rate_limit!, only: [:create]

  def show
    @doctors = @clinic.doctors.order(:name)
    @page_title = t("bookings.show.title", clinic: @clinic.name)
  end

  def slots
    doctor = @clinic.doctors.find_by(id: params[:doctor_id])
    date   = (Date.parse(params[:date].to_s) rescue nil)

    Rails.logger.debug { "[BookingsController#slots] slug=#{params[:slug]} doctor_id=#{params[:doctor_id].inspect} date=#{params[:date].inspect} → doctor=#{doctor&.name.inspect} date_parsed=#{date.inspect}" }

    if doctor.nil? || date.nil? || date < Date.current || date > 90.days.from_now.to_date
      Rails.logger.debug { "[BookingsController#slots] returning [] — doctor_nil=#{doctor.nil?} date_nil=#{date.nil?}" }
      render json: { slots: [] } and return
    end

    slot_list = available_slots(doctor, date)
    Rails.logger.debug { "[BookingsController#slots] returning #{slot_list.size} slots" }
    render json: { slots: slot_list }
  end

  def create
    name   = params[:patient_name].to_s.strip
    email  = params[:patient_email].to_s.strip.downcase
    phone  = params[:patient_phone].to_s.strip
    reason = params[:reason].to_s.strip
    doc_id = params[:doctor_id].to_s
    date_s = params[:appointment_date].to_s
    time_s = params[:appointment_time].to_s

    errs = []
    errs << t("bookings.errors.name_required")   if name.blank?
    errs << t("bookings.errors.email_required")  if email.blank?
    errs << t("bookings.errors.phone_required")  if phone.blank?
    errs << t("bookings.errors.doctor_required") if doc_id.blank?
    errs << t("bookings.errors.date_required")   if date_s.blank?
    errs << t("bookings.errors.time_required")   if time_s.blank?

    unless errs.empty?
      flash.now[:alert] = errs.join(" ")
      @doctors = @clinic.doctors.order(:name)
      render :show, status: :unprocessable_entity and return
    end

    doctor = @clinic.doctors.find_by(id: doc_id)
    date   = Date.parse(date_s) rescue nil
    time   = Time.parse(time_s) rescue nil

    if doctor.nil? || date.nil? || time.nil?
      flash.now[:alert] = t("bookings.errors.invalid_slot")
      @doctors = @clinic.doctors.order(:name)
      render :show, status: :unprocessable_entity and return
    end

    # Find existing patient by phone or create new
    patient = @clinic.patients.find_by(phone: phone) ||
              @clinic.patients.new(name: name, phone: phone, email: email)

    # Update email if patient exists but has no email
    patient.email = email if patient.email.blank? && email.present?

    unless patient.persisted? || patient.save
      flash.now[:alert] = t("bookings.errors.save_failed")
      @doctors = @clinic.doctors.order(:name)
      render :show, status: :unprocessable_entity and return
    end

    appointment = @clinic.appointments.new(
      doctor:           doctor,
      patient:          patient,
      appointment_date: date,
      appointment_time: time.strftime("%H:%M:%S"),
      status:           "pending",
      notes:            reason.presence,
      source:           "online",
      patient_email:    email
    )

    if appointment.save
      notify_clinic(appointment, name, email)
      redirect_to clinic_booking_confirmation_path(@clinic.slug)
    else
      flash.now[:alert] = appointment.errors.full_messages.first
      @doctors = @clinic.doctors.order(:name)
      render :show, status: :unprocessable_entity
    end
  end

  def confirmation
    @page_title = t("bookings.confirmation.title")
  end

  private

  def find_clinic
    @clinic = Clinic.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    render file: "public/404.html", status: :not_found, layout: false
  end

  def available_slots(doctor, date)
    return [] if date.saturday? || date.sunday?

    # Fall back to 09:00–17:00 if doctor has no working hours configured
    start_s = (doctor.work_start&.seconds_since_midnight || 9 * 3600).to_i
    end_s   = (doctor.work_end&.seconds_since_midnight   || 17 * 3600).to_i
    return [] if start_s >= end_s

    slots = []
    cur   = start_s
    while cur < end_s
      slots << format("%02d:%02d", cur / 3600, (cur % 3600) / 60)
      cur += 1800
    end

    booked = @clinic.appointments
                    .where(doctor_id: doctor.id, appointment_date: date)
                    .where.not(status: "cancelled")
                    .pluck(:appointment_time)
                    .map { |t| t.strftime("%H:%M") }

    slots.reject { |s| booked.include?(s) }
  end

  def check_rate_limit!
    key   = "booking_rate:#{request.remote_ip}"
    count = Rails.cache.read(key).to_i
    if count >= 10
      render plain: t("bookings.errors.rate_limit"), status: :too_many_requests
      return false
    end
    Rails.cache.write(key, count + 1, expires_in: 1.hour)
  end

  def notify_clinic(appointment, patient_name, patient_email)
    BookingMailer.clinic_notification(@clinic, appointment, patient_name, patient_email)
                 .deliver_later
  rescue StandardError => e
    Rails.logger.error("[BookingMailer] Failed to enqueue notification for appointment ##{appointment.id}: #{e.class}: #{e.message}")
  end
end
