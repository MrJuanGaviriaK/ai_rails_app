# Rails Developer Agent Memory

## Project: ai_rails_app

**Stack:** Rails 8.1.2 / Ruby 3.3.4 / PostgreSQL / Hotwire / Propshaft / RSpec + FactoryBot

---

## Schema (primary DB)

- `users` — Devise: `email`, `encrypted_password`, `name` (presence validated), standard Devise columns
- `roles` — rolify: `name` (NOT NULL), polymorphic `resource` refs, timestamps
- `users_roles` — join table (no PK), `user_id` + `role_id` FKs, unique composite index

## Key Architectural Patterns

- Multi-DB setup: 4 named DBs in production (`primary`, `cache`, `queue`, `cable`); dev/test uses one DB
- Migrations always go in `db/migrate/` for the primary DB
- Background jobs: Solid Queue in-process via Puma plugin; inherit from `ApplicationJob`
- Assets: Propshaft + ImportMap — no webpack/esbuild/npm bundling

## Authorization

- **rolify** gem (v6.0.1) installed on `User` model
- Three application roles: `admin`, `normal_user`, `client` (seeded in `db/seeds.rb`)
- `User` model has `rolify` macro before `devise`
- Role traits in `:user` factory use `after(:create)` (requires persisted user)
- FactoryBot traits: `create(:user, :admin)`, `create(:user, :client)`, `create(:user, :normal_user)`

## Testing Patterns

- `spec/support/` auto-require is enabled in `spec/rails_helper.rb`
- Shared examples live in `spec/support/shared_examples/`
- Shared example "a rolifiable model" in `spec/support/shared_examples/rolify.rb` — include with `it_behaves_like "a rolifiable model"`
- Role factory at `spec/factories/roles.rb` has traits `:admin`, `:normal_user`, `:client`

## Style Conventions (Omakase)

- Keyword args over hash rockets (e.g., `null: false` not `:null => false`)
- Double-quoted strings
- No trailing whitespace; no frozen string literal comments needed (enforced by rubocop-rails-omakase)
- Generator output often uses hash-rocket syntax — always convert before committing

## Common Pitfalls

- rolify generator uses old hash-rocket syntax — rewrite Role model and migration after generation
- rolify generator creates stub specs/factories — always overwrite with proper content
- Rolify initializer may have trailing whitespace on blank lines — clean up before running rubocop
- `spec/support/` auto-require is commented out by default in rails_helper.rb — must be uncommented

## Email / Devise Confirmable

- `:confirmable` enabled on User model; `allow_unconfirmed_access_for = 0.days`, `confirm_within = 3.days`, `paranoid = true`
- Custom Devise mailer: `Users::Mailer < Devise::Mailer` at `app/mailers/users/mailer.rb`; registered via `config.mailer = "Users::Mailer"` in devise.rb
- Welcome email: `UserMailer < ApplicationMailer` at `app/mailers/user_mailer.rb`; triggered by `after_commit :send_welcome_email, on: :update` in User model (guards: `saved_change_to_confirmed_at?` + `confirmed_at_before_last_save.nil?`)
- Dev delivery: `letter_opener` gem (in `group :development`)
- Production delivery: SendGrid SMTP relay; secrets `SENDGRID_API_KEY`, `ACTION_MAILER_HOST`, `MAILER_FROM_ADDRESS` from `.env` via `.kamal/secrets`
- Mailer views: `app/views/user_mailer/welcome_email.{html,text}.erb`
- `ApplicationMailer` default from: `ENV.fetch("MAILER_FROM_ADDRESS", "noreply@mail.mrjg.dev")`

## Confirmations Controller

- `Users::ConfirmationsController#show` overrides Devise to redirect to sign-in with `status: :see_other` (Turbo-safe)

## Bundle Install Pitfall

- The `.bundle/cache/compact_index/…/info-etags` directory is sometimes owned by root (from Docker/sudo runs), blocking `bundle install`. Workaround: `bundle install --full-index` bypasses the compact index entirely.
- The local `.bundle/config` may have `BUNDLE_WITHOUT: "development:test"` — clear it if gems need to be installed for all groups.

## Test Conventions (Mailer Specs)

- Omakase style requires spaces inside array literals: `eq([ "value" ])` not `eq(["value"])`
- Use `build_stubbed` for mailer unit tests (no DB needed); use `create` in integration specs
- `have_enqueued_mail(UserMailer, :welcome_email).with(user)` matcher for job assertions
- `config.before(:each) { ActionMailer::Base.deliveries.clear }` in rails_helper ensures delivery isolation

## Links

- Detailed patterns: `patterns.md` (not yet created)
