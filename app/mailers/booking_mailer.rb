class BookingMailer < ApplicationMailer
  def clinic_notification(clinic, appointment, patient_name, patient_email)
    @clinic        = clinic
    @appointment   = appointment
    @patient_name  = patient_name
    @patient_email = patient_email
    @doctor        = appointment.doctor

    mail(
      to:      clinic.user.email,
      subject: t("booking_mailer.clinic_notification.subject", clinic: clinic.name)
    )
  end

  def patient_confirmed(appointment)
    @appointment   = appointment
    @clinic        = appointment.clinic
    @doctor        = appointment.doctor
    @patient_name  = appointment.patient.name
    @patient_email = appointment.patient_email.presence || appointment.patient.email

    mail(
      to:      @patient_email,
      subject: t("booking_mailer.patient_confirmed.subject")
    )
  end

  def patient_rejected(appointment)
    @appointment   = appointment
    @clinic        = appointment.clinic
    @patient_name  = appointment.patient.name
    @patient_email = appointment.patient_email.presence || appointment.patient.email

    mail(
      to:      @patient_email,
      subject: t("booking_mailer.patient_rejected.subject")
    )
  end
end
