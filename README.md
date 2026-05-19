# ClinicFlow

ClinicFlow is a Rails 7.1 clinic management app for managing a clinic, doctors,
patients, appointments, and prescriptions inside a clinic-scoped dashboard.

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

3. Create and migrate the database:

   ```bash
   bin/rails db:prepare
   ```

4. Start the app:

   ```bash
   bin/rails server
   ```

5. Visit `http://localhost:3000`.

## Test suite

Run the test suite with:

```bash
bin/rails test
```

## Notes

- Authentication is handled with Devise.
- Every signed-in user is expected to manage records inside a single clinic.
- Users without a clinic are redirected to the clinic setup flow before
  accessing clinic-scoped pages.
