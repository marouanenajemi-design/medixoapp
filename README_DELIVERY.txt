================================================================================
  MEDIXOAPP — SOURCE CODE DELIVERY PACKAGE
  Professional SaaS Handover Documentation
================================================================================

PROJECT: MedixoApp
STACK:   Ruby on Rails 7.1 | PostgreSQL | Bootstrap | Devise | FullCalendar
SOLD ON: Flippa
DATE:    May 2026

================================================================================
  TABLE OF CONTENTS
================================================================================

  1. What Is Included
  2. System Requirements
  3. Environment Variables Reference
  4. Local Development Setup
  5. PostgreSQL Database Setup
  6. Running the Application
  7. Heroku Deployment Guide
  8. Email (SMTP) Configuration
  9. LemonSqueezy Billing Setup
  10. Generating a New Master Key
  11. Security Notes
  12. Application Features Overview

================================================================================
  1. WHAT IS INCLUDED
================================================================================

  - Full Ruby on Rails source code
  - Database migrations (db/migrate/)
  - Schema file (db/schema.rb)
  - Seed data file (db/seeds.rb)
  - All views, controllers, models, services
  - Gemfile and Gemfile.lock
  - Procfile for Heroku
  - Dockerfile for container deployment
  - Asset pipeline configuration
  - Multilingual support (English + French)

  NOT INCLUDED (by design — you must generate your own):
  - config/master.key  ← you MUST generate a new one (see Section 10)
  - .env files
  - Any API keys or credentials
  - Uploaded user files / patient data
  - Heroku account or GitHub access

================================================================================
  2. SYSTEM REQUIREMENTS
================================================================================

  - Ruby 3.2.3  (use rbenv or rvm to manage versions)
  - Rails 7.1.6
  - PostgreSQL 14+ (local or managed, e.g. Heroku Postgres, Supabase, Render)
  - Bundler 2.x
  - Node.js 18+ (for asset pipeline)
  - Git

  Install rbenv (recommended):
    https://github.com/rbenv/rbenv#installation

  Install Ruby 3.2.3:
    rbenv install 3.2.3
    rbenv local 3.2.3

================================================================================
  3. ENVIRONMENT VARIABLES REFERENCE
================================================================================

  The following environment variables MUST be set before running the app.
  Set them in your shell, a .env file (never commit it), or your hosting
  platform's dashboard (Heroku Config Vars, Render Environment, etc.).

  ┌─────────────────────────────────┬───────────────────────────────────────────────────────┐
  │ Variable                        │ Description                                           │
  ├─────────────────────────────────┼───────────────────────────────────────────────────────┤
  │ RAILS_MASTER_KEY                │ Generated via `rails credentials:edit` (see Sec. 10) │
  │ SECRET_KEY_BASE                 │ Generated via `bundle exec rails secret`              │
  │ DATABASE_URL                    │ Full PostgreSQL connection string (production only)   │
  │ CLINIC_SAAS_DATABASE_PASSWORD   │ PostgreSQL password (fallback if not using DB URL)   │
  │ LEMON_SQUEEZY_WEBHOOK_SECRET    │ From your LemonSqueezy dashboard > Webhooks           │
  │ SMTP_ADDRESS                    │ SMTP server address (default: smtp.sendgrid.net)      │
  │ SMTP_USERNAME                   │ SMTP username (SendGrid: "apikey")                   │
  │ SMTP_PASSWORD                   │ SMTP password or API key                             │
  │ SMTP_DOMAIN                     │ Your domain, e.g. yourdomain.com                     │
  │ SMTP_PORT                       │ SMTP port (default: 587)                             │
  │ APP_HOST                        │ Your production domain, e.g. yourdomain.com          │
  │ RAILS_SERVE_STATIC_FILES        │ Set to "true" on Heroku/Render                       │
  │ RAILS_LOG_LEVEL                 │ Optional. Default: "info"                            │
  │ MAILER_PERFORM_DELIVERIES       │ Optional. Default: "true"                            │
  └─────────────────────────────────┴───────────────────────────────────────────────────────┘

================================================================================
  4. LOCAL DEVELOPMENT SETUP
================================================================================

  Step 1 — Clone / extract the source code
    Extract the ZIP to a directory of your choice.
    cd medixoapp

  Step 2 — Install Ruby dependencies
    gem install bundler
    bundle install

  Step 3 — Generate a new master key (REQUIRED — see Section 10)

  Step 4 — Set up the database (see Section 5)

  Step 5 — Run the development server
    bin/rails server

  Step 6 — Open in browser
    http://localhost:3000

================================================================================
  5. POSTGRESQL DATABASE SETUP
================================================================================

  Install PostgreSQL:
    Ubuntu/Debian:  sudo apt install postgresql postgresql-contrib
    macOS:          brew install postgresql
    Windows:        https://www.postgresql.org/download/windows/

  Start PostgreSQL service:
    Ubuntu:  sudo service postgresql start
    macOS:   brew services start postgresql

  Create a database user:
    sudo -u postgres psql
    CREATE USER medixoapp WITH PASSWORD 'your_secure_password';
    CREATE DATABASE clinic_saas_development OWNER medixoapp;
    CREATE DATABASE clinic_saas_test OWNER medixoapp;
    \q

  Run migrations:
    bundle exec rails db:migrate

  (Optional) Seed with sample data:
    bundle exec rails db:seed

  Check schema was applied:
    bundle exec rails db:schema:load   # alternative to migrations on fresh DB

================================================================================
  6. RUNNING THE APPLICATION
================================================================================

  Development:
    bin/rails server
    # Visit http://localhost:3000

  Run tests:
    bundle exec rails test

  Open Rails console:
    bin/rails console

  Check routes:
    bin/rails routes

================================================================================
  7. HEROKU DEPLOYMENT GUIDE
================================================================================

  Prerequisites:
    - Heroku CLI installed: https://devcenter.heroku.com/articles/heroku-cli
    - Your own Heroku account (free tier works for testing)

  Step 1 — Create a Heroku app
    heroku create your-app-name

  Step 2 — Add PostgreSQL add-on
    heroku addons:create heroku-postgresql:essential-0

  Step 3 — Set environment variables
    heroku config:set RAILS_MASTER_KEY=<your_new_master_key>
    heroku config:set SECRET_KEY_BASE=$(bundle exec rails secret)
    heroku config:set RAILS_SERVE_STATIC_FILES=true
    heroku config:set APP_HOST=your-app-name.herokuapp.com
    heroku config:set LEMON_SQUEEZY_WEBHOOK_SECRET=<your_ls_secret>
    heroku config:set SMTP_ADDRESS=smtp.sendgrid.net
    heroku config:set SMTP_USERNAME=apikey
    heroku config:set SMTP_PASSWORD=<your_sendgrid_api_key>
    heroku config:set SMTP_DOMAIN=your-domain.com

  Step 4 — Deploy
    git push heroku main

  Step 5 — Run migrations
    heroku run rails db:migrate

  Step 6 — Open the app
    heroku open

  Useful Heroku commands:
    heroku logs --tail           # stream live logs
    heroku run rails console     # open production console
    heroku config                # view all environment variables

================================================================================
  8. EMAIL (SMTP) CONFIGURATION
================================================================================

  The app is pre-configured to use SendGrid (or any SMTP provider).

  Recommended free option: SendGrid
    1. Sign up at https://sendgrid.com
    2. Create an API key with "Mail Send" permission
    3. Set these environment variables:
       SMTP_ADDRESS=smtp.sendgrid.net
       SMTP_USERNAME=apikey
       SMTP_PASSWORD=<your_api_key>
       SMTP_DOMAIN=your-domain.com

  Alternative providers (same variables, different values):
    - Mailgun: smtp.mailgun.org
    - Postmark: smtp.postmarkapp.com
    - AWS SES: email-smtp.<region>.amazonaws.com

================================================================================
  9. LEMONSQUEEZY BILLING SETUP
================================================================================

  MedixoApp uses LemonSqueezy for subscription billing.

  Step 1 — Create account at https://lemonsqueezy.com

  Step 2 — Create a product and pricing plan

  Step 3 — Configure a webhook endpoint:
    URL: https://your-domain.com/webhooks/lemonsqueezy
    Events to enable:
      - subscription_created
      - subscription_updated
      - subscription_cancelled
      - subscription_expired

  Step 4 — Copy the webhook signing secret and set:
    LEMON_SQUEEZY_WEBHOOK_SECRET=<your_secret>

  The webhook handler is in:
    app/controllers/webhooks_controller.rb

  Billing fields are stored on the Clinic model:
    subscribed, plan, billing_customer_id, billing_subscription_id

================================================================================
  10. GENERATING A NEW MASTER KEY
================================================================================

  IMPORTANT: The original master.key is NOT included in this package.
  You must generate a fresh one. This is standard and correct practice.

  Step 1 — Remove any existing encrypted credentials:
    rm -f config/credentials.yml.enc

  Step 2 — Generate new credentials (this creates a new master.key):
    EDITOR="nano" bundle exec rails credentials:edit

  Step 3 — Add your secrets inside the editor, e.g.:
    secret_key_base: <run `bundle exec rails secret` and paste here>

  Step 4 — Save and close the editor.
    Rails will write config/credentials.yml.enc and config/master.key.

  Step 5 — Copy the master key value:
    cat config/master.key

  Step 6 — Set it as an environment variable on your hosting platform:
    RAILS_MASTER_KEY=<value from step 5>

  SECURITY: Never commit config/master.key to git.
  Confirm it is in your .gitignore:
    grep master.key .gitignore

================================================================================
  11. SECURITY NOTES
================================================================================

  - config/master.key is gitignored and was NOT delivered — generate your own
  - All API keys and secrets are loaded from environment variables, never hardcoded
  - The app enforces SSL in production (config.force_ssl = true)
  - Devise handles authentication with bcrypt password hashing
  - LemonSqueezy webhook signatures are verified using HMAC-SHA256
  - Filter parameter logging is configured to mask :password fields
  - Change the default admin/user credentials immediately after setup
  - Enable 2FA on all third-party accounts (Heroku, LemonSqueezy, SendGrid)

================================================================================
  12. APPLICATION FEATURES OVERVIEW
================================================================================

  Authentication:
    - User registration and login (Devise)
    - Password reset via email

  Clinic Management:
    - Clinic profile setup (name, address, billing info)
    - Subscription management via LemonSqueezy

  Doctor Management:
    - Add / edit / delete doctors
    - Doctor profiles

  Patient Management:
    - Patient records
    - Patient history view

  Appointments:
    - Create / manage appointments
    - Calendar view (FullCalendar integration)

  Prescriptions:
    - Create prescriptions with multiple items
    - Printable prescription view

  Medicine Chatbot:
    - Built-in knowledge base (no external AI API needed)
    - Supports English and French
    - Covers: Ibuprofen, Paracetamol, Amoxicillin, Cetirizine

  Billing:
    - LemonSqueezy subscription integration
    - Webhook-driven subscription activation/deactivation

  Internationalisation:
    - English and French locale files included

================================================================================
  END OF DOCUMENTATION
  For questions during setup, refer to the Rails guides: https://guides.rubyonrails.org
================================================================================
