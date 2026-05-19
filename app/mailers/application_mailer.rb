class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "no-reply@medixoapp.com")
  layout "mailer"
end
