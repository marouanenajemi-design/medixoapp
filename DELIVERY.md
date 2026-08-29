# MedixoApp — Delivery & Setup Guide

**Version:** 1.0.0  
**Delivered:** May 2026  
**Stack:** Ruby on Rails 7.1 · PostgreSQL · Bootstrap 5 · Devise · FullCalendar

---

## Table of Contents

1. [What Is Included](#1-what-is-included)
2. [System Requirements](#2-system-requirements)
3. [Required Environment Variables](#3-required-environment-variables)
4. [Local Development Setup](#4-local-development-setup)
5. [PostgreSQL Setup](#5-postgresql-setup)
6. [Generate Your Master Key](#6-generate-your-master-key)
7. [Creating Your Super Admin Account](#7-creating-your-super-admin-account)
8. [Admin Panel Access](#8-admin-panel-access)
9. [Deploying to Heroku](#9-deploying-to-heroku)
10. [LemonSqueezy Billing Setup](#10-lemonsqueezy-billing-setup)
11. [Email (SMTP) Configuration](#11-email-smtp-configuration)
12. [Security Checklist](#12-security-checklist)

---

## 1. What Is Included

```
medixoapp/
├── app/
│   ├── controllers/
│   │   ├── admin/                  ← Super Admin Panel (NEW)
│   │   │   ├── base_controller.rb
│   │   │   ├── dashboard_controller.rb
│   │   │   ├── users_controller.rb
│   │   │   ├── clinics_controller.rb
│   │   │   ├── doctors_controller.rb
│   │   │   ├── patients_controller.rb
│   │   │   └── appointments_controller.rb
│   │   ├── application_controller.rb
│   │   ├── dashboard_controller.rb
│   │   ├── doctors_controller.rb
│   │   ├── patients_controller.rb
│   │   ├── appointments_controller.rb
│   │   ├── prescriptions_controller.rb
│   │   ├── clinics_controller.rb
│   │   ├── chatbot_controller.rb
│   │   └── webhooks_controller.rb
│   ├── models/
│   │   ├── user.rb                 ← super_admin boolean added
│   │   ├── clinic.rb               ← subscription/trial logic
│   │   ├── doctor.rb
│   │   ├── patient.rb
│   │   ├── appointment.rb
│   │   ├── prescription.rb
│   │   └── prescription_item.rb
│   ├── views/
│   │   ├── layouts/
│   │   │   ├── admin.html.erb      ← Admin layout (purple sidebar)
│   │   │   └── application.html.erb
│   │   ├── admin/                  ← All admin panel views (NEW)
│   │   └── [all clinic views]
│   ├── services/
│   │   └── medicine_chatbot_service.rb
│   └── javascript/controllers/    ← Stimulus controllers
├── config/
│   ├── routes.rb                   ← Admin namespace added
│   ├── credentials.yml.enc         ← Encrypted (safe to ship)
│   ├── database.yml
│   ├── environments/
│   │   └── production.rb           ← SMTP, SSL, host config
│   └── locales/
│       ├── en.yml                  ← English + admin translations
│       └── fr.yml                  ← French + admin translations
├── db/
│   ├── migrate/                    ← All migrations including super_admin
│   ├── schema.rb
│   └── seeds.rb
├── Gemfile / Gemfile.lock
├── Procfile                        ← Heroku process config
└── Dockerfile
```

**NOT included (intentionally):**
- `config/master.key` — generate your own (Section 6)
- `.env` files — set environment variables directly
- `storage/` uploads — patient data, not transferable
- `log/` files — runtime logs
- `.git/` — version history

---

## 2. System Requirements

| Requirement | Version |
|-------------|---------|
| Ruby | 3.2.3 |
| Rails | 7.1.6 |
| PostgreSQL | 14+ |
| Bundler | 2.x |
| Node.js | 18+ (for asset pipeline) |

**Install Ruby 3.2.3 with rbenv:**
```bash
rbenv install 3.2.3
rbenv local 3.2.3
ruby -v   # should print ruby 3.2.3
```

---

## 3. Required Environment Variables

Set these in your hosting platform's dashboard (Heroku Config Vars, Render, Railway) or in a local `.env` file (never commit `.env`).

| Variable | Required | Description |
|----------|----------|-------------|
| `RAILS_MASTER_KEY` | **YES** | Generated in Section 6 |
| `SECRET_KEY_BASE` | **YES** | Run: `bundle exec rails secret` |
| `DATABASE_URL` | **YES (production)** | Full PostgreSQL connection URL |
| `CLINIC_SAAS_DATABASE_PASSWORD` | dev fallback | DB password if not using DATABASE_URL |
| `LEMON_SQUEEZY_WEBHOOK_SECRET` | **YES** | From your LemonSqueezy dashboard |
| `SMTP_ADDRESS` | **YES** | SMTP server (default: smtp.sendgrid.net) |
| `SMTP_USERNAME` | **YES** | SMTP username (SendGrid: `apikey`) |
| `SMTP_PASSWORD` | **YES** | SMTP password or API key |
| `SMTP_DOMAIN` | **YES** | Your domain (e.g. `yourdomain.com`) |
| `APP_HOST` | **YES** | Your domain (e.g. `yourdomain.com`) |
| `RAILS_SERVE_STATIC_FILES` | Heroku/Render | Set to `true` |
| `RAILS_LOG_LEVEL` | optional | Default: `info` |

---

## 4. Local Development Setup

```bash
# 1. Extract the ZIP and enter the directory
unzip medixoapp_delivery_*.zip
cd medixoapp/

# 2. Install Ruby dependencies
gem install bundler
bundle install

# 3. Generate master key (Section 6 — do this before anything else)

# 4. Set up the database (Section 5)

# 5. Run the server
bin/rails server

# 6. Open in browser
open http://localhost:3000
```

---

## 5. PostgreSQL Setup

```bash
# Start PostgreSQL
sudo service postgresql start       # Linux
brew services start postgresql      # macOS

# Create database user and databases
sudo -u postgres psql

  CREATE USER medixoapp WITH PASSWORD 'choose_a_strong_password';
  CREATE DATABASE clinic_saas_development OWNER medixoapp;
  CREATE DATABASE clinic_saas_test OWNER medixoapp;
  \q

# Run migrations
bundle exec rails db:migrate

# Optional: load sample seed data
bundle exec rails db:seed
```

---

## 6. Generate Your Master Key

The `config/master.key` is **not included** in this package. You must generate a fresh one — this is the correct and secure way to take ownership of the app.

```bash
# Step 1 — Remove the existing encrypted credentials (tied to old key)
rm -f config/credentials.yml.enc

# Step 2 — Generate new credentials (creates config/master.key automatically)
EDITOR="nano" bundle exec rails credentials:edit

# Step 3 — Inside the editor, add:
#   secret_key_base: <paste output of: bundle exec rails secret>
# Save and close.

# Step 4 — View your new master key
cat config/master.key

# Step 5 — Set as environment variable on your hosting platform
RAILS_MASTER_KEY=<your key value>
```

> **Security:** Never commit `config/master.key` to git. Confirm it is in `.gitignore`:
> ```bash
> grep master.key .gitignore   # should print: /config/master.key
> ```

---

## 7. Creating Your Super Admin Account

The Super Admin Panel is built into the app. To access it, you need to promote a user account to super admin status.

### Step 1 — Register a normal account

Visit `http://localhost:3000/users/sign_up` (or your production URL) and create an account with your admin email and a strong password.

### Step 2 — Promote the account to Super Admin

Open a Rails console:

```bash
# Local development
bundle exec rails console

# Heroku production
heroku run rails console
```

Run this command (replace with your actual email):

```ruby
User.find_by(email: "admin@yourdomain.com").update!(super_admin: true)
```

Confirm it worked:

```ruby
User.find_by(email: "admin@yourdomain.com").super_admin?
# => true
```

Exit the console:

```ruby
exit
```

### Super Admin Credentials

```
Email:    [the email you registered with in Step 1]
Password: [the password you chose in Step 1]
```

> These credentials are **yours to set**. No default credentials are shipped.
> Choose a strong password (12+ characters, mixed case, numbers, symbols).

---

## 8. Admin Panel Access

| URL | Description |
|-----|-------------|
| `http://your-domain.com/admin` | Super Admin Panel root |
| `http://your-domain.com/admin/users` | Manage all users |
| `http://your-domain.com/admin/clinics` | Manage all clinics & subscriptions |
| `http://your-domain.com/admin/doctors` | View all doctors platform-wide |
| `http://your-domain.com/admin/patients` | View all patients platform-wide |
| `http://your-domain.com/admin/appointments` | View all appointments platform-wide |

### Admin Panel Capabilities

| Section | Actions |
|---------|---------|
| **Dashboard** | Platform stats: total users, clinics, doctors, patients, appointments. Subscription breakdown (subscribed / trialing / expired). Recent signups and recent clinics. |
| **Users** | List all users. Promote/demote super admin role. Delete user (cascades to clinic). |
| **Clinics** | List all clinics. Manually activate or deactivate subscription. Extend trial by 7 days. View billing IDs. Delete clinic. |
| **Doctors** | Read-only view of all doctors across all clinics. |
| **Patients** | Read-only view of all patients across all clinics. |
| **Appointments** | Read-only view of all appointments with status badges. |

**Visual distinction:** The admin panel uses a **purple sidebar** with an amber shield badge — clearly separate from the clinic panel's dark navy sidebar.

**Security:** Regular users who attempt to visit `/admin` are immediately redirected to the dashboard with an "Access denied" message. The gate is enforced at the controller level, not just the UI.

---

## 9. Deploying to Heroku

```bash
# Install Heroku CLI: https://devcenter.heroku.com/articles/heroku-cli

# Create app
heroku create your-app-name

# Add PostgreSQL
heroku addons:create heroku-postgresql:essential-0

# Set all environment variables
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
heroku config:set SECRET_KEY_BASE=$(bundle exec rails secret)
heroku config:set RAILS_SERVE_STATIC_FILES=true
heroku config:set APP_HOST=your-app-name.herokuapp.com
heroku config:set LEMON_SQUEEZY_WEBHOOK_SECRET=your_ls_secret
heroku config:set SMTP_ADDRESS=smtp.sendgrid.net
heroku config:set SMTP_USERNAME=apikey
heroku config:set SMTP_PASSWORD=your_sendgrid_api_key
heroku config:set SMTP_DOMAIN=your-domain.com

# Deploy
git init
git add .
git commit -m "Initial deployment"
heroku git:remote -a your-app-name
git push heroku main

# Run migrations
heroku run rails db:migrate

# Create super admin (see Section 7)
heroku run rails console

# Open the app
heroku open
```

**Useful Heroku commands:**
```bash
heroku logs --tail          # stream live logs
heroku run rails console    # open production console
heroku config               # view all environment variables
heroku restart              # restart all dynos
```

---

## 10. LemonSqueezy Billing Setup

The app has a built-in LemonSqueezy webhook handler at `/webhooks/lemonsqueezy`.

```
1. Create account at https://lemonsqueezy.com
2. Create a Store, then a Product with a subscription pricing plan
3. Go to Settings → Webhooks → Add webhook:
     URL:    https://your-domain.com/webhooks/lemonsqueezy
     Events: subscription_created
             subscription_updated
             subscription_cancelled
             subscription_expired
4. Copy the Webhook Signing Secret
5. Set environment variable:
     LEMON_SQUEEZY_WEBHOOK_SECRET=<your secret>
```

The webhook automatically activates/deactivates the `subscribed` flag on the user's clinic when a subscription event is received.

---

## 11. Email (SMTP) Configuration

**Recommended: SendGrid (free up to 100 emails/day)**

```
1. Sign up at https://sendgrid.com
2. Create an API key with "Mail Send" permission
3. Set environment variables:
     SMTP_ADDRESS=smtp.sendgrid.net
     SMTP_USERNAME=apikey
     SMTP_PASSWORD=<your SendGrid API key>
     SMTP_DOMAIN=your-domain.com
```

**Alternative providers:**
| Provider | SMTP Address |
|----------|-------------|
| Mailgun | smtp.mailgun.org |
| Postmark | smtp.postmarkapp.com |
| AWS SES | email-smtp.us-east-1.amazonaws.com |

---

## 12. Security Checklist

Complete these before going live:

- [ ] Generated a fresh `config/master.key` (Section 6)
- [ ] Set `RAILS_MASTER_KEY` as an environment variable
- [ ] Set `SECRET_KEY_BASE` as an environment variable
- [ ] `config/master.key` is in `.gitignore` and NOT committed
- [ ] Created your super admin account (Section 7)
- [ ] Changed default passwords on all third-party services
- [ ] Enabled 2FA on Heroku, SendGrid, LemonSqueezy accounts
- [ ] Set `APP_HOST` to your actual domain
- [ ] Verified HTTPS is enforced (Heroku SSL or custom certificate)
- [ ] Tested password reset email is delivered
- [ ] Tested LemonSqueezy webhook with a test event
- [ ] Verified `/admin` is inaccessible without super admin account

---

*MedixoApp — Clinic management made simple.*
