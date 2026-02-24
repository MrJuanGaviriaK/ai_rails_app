# AI Rails App

A Rails 8 web application with user authentication, role-based authorization, background job processing, and real-time features. Built with a modern, no-Node-bundler stack: Hotwire, ImportMap, Propshaft, and database-backed adapters for jobs, caching, and WebSockets.

---

## Prerequisites

| Requirement | Version |
|---|---|
| Ruby | 3.3.4 (see `.ruby-version`) |
| Rails | 8.1.2 |
| PostgreSQL | 13+ |
| Bundler | Latest (`gem install bundler`) |

Install Ruby via [rbenv](https://github.com/rbenv/rbenv) or [mise](https://mise.jdx.dev/):

```bash
rbenv install 3.3.4
# or
mise install ruby 3.3.4
```

PostgreSQL must be running locally and accepting connections via a Unix socket (the default on macOS/Linux). No username or password is required for local development by default.

---

## Local Setup

### 1. Clone the repo

```bash
git clone <repo-url>
cd ai_rails_app
```

### 2. Configure environment variables

Copy the example below into a `.env` file at the project root. In development, only the email variables are required if you want to test mailers; they can be left as placeholders otherwise.

```bash
# .env (development only — never commit secrets)

# Email — development uses letter_opener (browser preview), so these
# values are only needed if you switch to real delivery.
ACTION_MAILER_HOST=localhost:3000
SENDGRID_API_KEY=           # not needed in development
MAILER_FROM_ADDRESS=noreply@example.com

# Production-only — leave blank for local development
DB_HOST=
KAMAL_REGISTRY_USERNAME=
KAMAL_REGISTRY_PASSWORD=
KAMAL_PROXY_HOST=
RAILS_MASTER_KEY=
```

`dotenv-rails` loads `.env` automatically in the `development` and `test` environments.

### 3. Install dependencies and set up the database

```bash
bin/setup
```

This script is **idempotent** — safe to run multiple times. It:
- Runs `bundle install`
- Creates and migrates the database (`db:prepare`)
- Clears logs and tmp files
- Starts the development server (`bin/dev`)

To set up without starting the server:

```bash
bin/setup --skip-server
```

To wipe and recreate the database from scratch:

```bash
bin/setup --reset
```

---

## Running the App

```bash
bin/dev
```

The server starts on [http://localhost:3000](http://localhost:3000).

Solid Queue runs **in-process** inside Puma (no separate worker process needed in development). Background jobs are processed automatically alongside the web server.

### Other useful commands

```bash
bin/rails console          # Open a Rails REPL
bin/rails db:migrate       # Run pending migrations
bin/rails routes           # List all routes
bin/rails dev:cache        # Toggle development caching on/off
```

### Email in development

Outgoing emails are intercepted by [letter_opener](https://github.com/ryanb/letter_opener) and opened automatically in your browser — no real email is sent. After a user registers and confirms their account, a welcome email will pop up in the browser.

### Job monitoring

A web UI for inspecting Solid Queue jobs is mounted at [http://localhost:3000/jobs](http://localhost:3000/jobs) via [Mission Control Jobs](https://github.com/rails/mission_control-jobs).

---

## Environment Variables Reference

| Variable | Required in dev? | Description |
|---|---|---|
| `ACTION_MAILER_HOST` | No | Host used in mailer URL helpers |
| `SENDGRID_API_KEY` | No | SendGrid API key (production email delivery) |
| `MAILER_FROM_ADDRESS` | No | From address for outgoing emails |
| `DB_HOST` | No | Production database connection string |
| `RAILS_MASTER_KEY` | No | Decrypts `config/credentials.yml.enc` |
| `KAMAL_REGISTRY_USERNAME` | No | Docker registry username (deploy only) |
| `KAMAL_REGISTRY_PASSWORD` | No | Docker registry token (deploy only) |
| `KAMAL_PROXY_HOST` | No | Public hostname for kamal-proxy (deploy only) |

---

## Running Tests

```bash
bundle exec rspec                                      # All specs
bundle exec rspec spec/models/                         # Model specs only
bundle exec rspec spec/path/to/file_spec.rb            # Single file
bundle exec rspec spec/path/to/file_spec.rb:42         # Specific line
```

System specs use Selenium with a headless Chrome browser (Capybara). Chrome or Chromium must be installed for system tests to run.

---

## Linting and Security Checks

These checks run in CI and must pass before merging.

```bash
bin/rubocop          # Lint with RuboCop Omakase (Rails style guide)
bin/rubocop -a       # Auto-correct safe offences

bin/brakeman         # Static security analysis
bin/bundler-audit    # Audit gems for known CVEs
```

The CI pipeline (`.github/workflows/ci.yml`) also runs an importmap audit via `bin/importmap audit`.

---

## Architecture Notes

### Database

Development uses a single PostgreSQL database (`ai_rails_app_development`). Production is split into four named databases, each with its own migration path:

| Name | Database | Migration path |
|---|---|---|
| `primary` | `ai_rails_app_production` | `db/migrate/` |
| `cache` | `ai_rails_app_production_cache` | `db/cache_migrate/` |
| `cable` | `ai_rails_app_production_cable` | `db/cable_migrate/` |
| `queue` | `ai_rails_app_production_queue` | `db/queue_migrate/` |

Always place new migrations in the correct directory. Migrations for application models go in `db/migrate/`.

### Background Jobs — Solid Queue

Jobs inherit from `ApplicationJob` and are processed by Solid Queue. In development and production, Solid Queue runs **inside the Puma process** (configured via `config/puma.rb` and the `SOLID_QUEUE_IN_PUMA: true` env var). No separate worker process or Redis instance is needed.

### Caching — Solid Cache

The Rails cache store uses Solid Cache (database-backed) in production. In development, `:memory_store` is used by default. Toggle development caching with `bin/rails dev:cache`.

### WebSockets — Solid Cable

Action Cable uses Solid Cable (database-backed adapter) in production, eliminating the need for a separate Redis instance.

### Asset Pipeline

Uses **Propshaft** (not Sprockets) with **ImportMap** (no webpack, esbuild, or Node bundler). JavaScript modules are pinned in `config/importmap.rb`. Stylesheets live in `app/assets/stylesheets/`. TailwindCSS is compiled via the `tailwindcss-rails` gem.

### Authentication and Authorization

- **Devise** handles authentication with the `database_authenticatable`, `registerable`, `recoverable`, `rememberable`, `validatable`, and `confirmable` modules. Email confirmation is required before a user can sign in.
- **Rolify** manages roles. New users are automatically assigned the `normal_user` role on creation.

---

## Deployment

The app is deployed with **Kamal** (Docker-based). Kamal configuration lives in `config/deploy.yml`. Production secrets are stored in `.kamal/secrets` (not in `.env`).

```bash
bin/kamal setup      # First-time deploy (provisions server)
bin/kamal deploy     # Deploy a new version
bin/kamal console    # Open a Rails console on the production server
bin/kamal logs       # Tail production logs
```

The production server is an amd64 Linux host. If you are building on Apple Silicon (arm64), the Docker image is cross-compiled for `linux/amd64` automatically via the `builder.arch: amd64` setting in `config/deploy.yml`.
