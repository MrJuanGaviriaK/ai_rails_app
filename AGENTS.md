# AGENTS.md

## Fastest reliable workflow
- Use `bin/setup --skip-server` for first-time setup; `bin/setup` will start `bin/dev` at the end.
- Use `bin/dev` to run local dev; it starts Foreman with `Procfile.dev` (`web` + Tailwind watcher).
- Primary test suite is RSpec (`spec/`): `bundle exec rspec`, `bundle exec rspec spec/path/file_spec.rb[:line]`.
- For CI-like verification, run: `bin/rubocop` -> `bin/brakeman --no-pager` -> `bin/bundler-audit` -> `bin/importmap audit` -> `bin/rails db:test:prepare && bundle exec rspec`.

## Stack and wiring that are easy to guess wrong
- This app uses ImportMap + Propshaft + `tailwindcss-rails` (no Node bundler, no `package.json`).
- `config/puma.rb` runs Solid Queue inside Puma in development, and in production when `SOLID_QUEUE_IN_PUMA` is set.
- Production Action Cable is currently Redis-backed (`config/cable.yml`), even though `solid_cable` gem is present.
- Development cache store is `:memory_store`; test uses `:null_store`.

## Database and migrations
- Development/test use single Postgres DBs (`ai_rails_app_development`, `ai_rails_app_test`).
- Production uses multi-db config in `config/database.yml` (`primary`, `cache`, `cable`), with extra migration paths for cache/cable.
- App model migrations belong in `db/migrate/`.

## Auth and app behavior conventions
- `ApplicationController` enforces `authenticate_user!` globally; unauthenticated requests are redirected to Devise flows.
- `User` is Devise `:confirmable`; a welcome email is queued only on first confirmation (`after_commit` on `confirmed_at` change).
- User management roles are `superadmin`, `admin`, `buyer`, and `client`.

## Deployment facts to preserve
- Deploys use Kamal (`config/deploy.yml`); image builds are forced to `amd64`.
- Runtime/deploy secrets are expected via env vars (`DB_HOST`, `RAILS_MASTER_KEY`, SendGrid/mailer vars, Kamal registry vars).
