# MedixoApp

MedixoApp is a Rails 7.1 SaaS clinic management platform for managing doctors,
patients, appointments, prescriptions, and online bookings inside a
multi-tenant clinic dashboard.

## Requirements

- Ruby 3.2.3
- Bundler 2.4.19 or newer in the Ruby 3.2 series
- PostgreSQL

The Ruby version is standardized in both `Gemfile` and `.ruby-version` so local
development, CI, and deployment use the same runtime.

## Setup

1. Install Ruby `3.2.3`.
2. Install dependencies:

   ```bash
   bundle install
   ```

3. Copy the environment template and fill in your values:

   ```bash
   cp .env.example .env
   ```

4. Create and migrate the database:

   ```bash
   bin/rails db:prepare
   ```

5. Start the app:

   ```bash
   bin/rails server
   ```

6. Visit `http://localhost:3000`.

## Environment variables

All configuration is driven by environment variables. See `.env.example` for
the full list with descriptions. The minimum required for production:

| Variable | Description |
|---|---|
| `SECRET_KEY_BASE` | Rails secret key (`rails secret`) |
| `DATABASE_URL` | PostgreSQL connection string |
| `APP_HOST` | Public hostname (e.g. `medixoapp.com`) |
| `MAILER_FROM` | From address on outgoing emails |
| `SMTP_USER_NAME` | SMTP username / API token |
| `SMTP_PASSWORD` | SMTP password / API token |

## Email setup

MedixoApp sends transactional emails (booking notifications, etc.) via SMTP.
The super-admin dashboard shows a warning banner when `SMTP_USER_NAME` or
`SMTP_PASSWORD` are not set.

### Postmark (recommended)

1. Create a free account at <https://postmarkapp.com> and add a Server.
2. Copy the **Server API Token** (used for both username and password).
3. Set in your environment:

   ```
   SMTP_ADDRESS=smtp.postmarkapp.com
   SMTP_PORT=587
   SMTP_DOMAIN=yourdomain.com
   SMTP_USER_NAME=your-postmark-server-token
   SMTP_PASSWORD=your-postmark-server-token
   SMTP_AUTHENTICATION=plain
   SMTP_ENABLE_STARTTLS_AUTO=true
   MAILER_FROM=no-reply@yourdomain.com
   ```

4. Verify delivery by sending a test email:

   ```bash
   bin/rails runner "BookingMailer.clinic_notification(Clinic.first, Appointment.first, 'Test Patient', 'test@example.com').deliver_now"
   ```

### SendGrid alternative

```
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER_NAME=apikey
SMTP_PASSWORD=your-sendgrid-api-key
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true
```

### Background job adapter (production)

By default Rails uses the `:async` adapter which loses jobs on restart.
For production, configure a persistent queue backend. Uncomment and set in
`config/environments/production.rb`:

```ruby
config.active_job.queue_adapter = :sidekiq
```

Or use Solid Queue (included since Rails 8):

```ruby
config.active_job.queue_adapter = :solid_queue
```

Without a persistent adapter, `deliver_later` email jobs will be lost if the
process restarts. `deliver_now` can be used as a simpler alternative for low
traffic.

## Test suite

Run the test suite with:

```bash
bin/rails test
```

## Notes

- Authentication is handled with Devise.
- Every signed-in user manages records inside a single clinic (multi-tenant).
- Users without a clinic are redirected to the clinic setup flow before
  accessing clinic-scoped pages.
- Online booking pages are public at `/book/:clinic_slug` — no login required.
- Email delivery errors are logged (not silently swallowed); booking creation
  succeeds even if email enqueueing fails.
