# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Tech Stack

- **Ruby 3.3.4 / Rails 8.1.2** with PostgreSQL
- **Frontend:** Hotwire (Turbo + Stimulus), ImportMap, Propshaft asset pipeline
- **Background jobs:** Solid Queue (via Puma plugin)
- **Caching:** Solid Cache; **WebSockets:** Solid Cable
- **Deployment:** Docker + Kamal
- **Testing:** RSpec + FactoryBot

## Common Commands

```bash
bin/setup              # Initial dev setup (idempotent; use --reset to wipe DB)
bin/dev                # Start development server (Puma on port 3000)
bin/rails console      # Rails REPL

bundle exec rspec                        # Run all specs
bundle exec rspec spec/path/to/file_spec.rb  # Run a single spec file
bundle exec rspec spec/path/to/file_spec.rb:42  # Run spec at a specific line

bin/rubocop            # Lint (Omakase Rails style)
bin/brakeman           # Security scan
bin/bundler-audit      # Gem vulnerability audit
```

## Architecture Notes

**Multi-database production setup:** Rails is configured with four named databases in production — `primary`, `cache`, `queue`, and `cable` — each with its own migration path (`db/migrate`, `db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`). In development, only the primary PostgreSQL database is used.

**Asset pipeline:** Uses Propshaft (not Sprockets) + ImportMap (no bundler/transpiler). JavaScript is loaded via import maps in `config/importmap.rb`; CSS lives in `app/assets/stylesheets/`.

**Background jobs:** Solid Queue runs in-process via the Puma plugin (configured in `config/puma.rb`). Jobs inherit from `ApplicationJob`.

**Testing:** RSpec is the test framework (`spec/`). FactoryBot factories live in `spec/factories/`. Load factories in `spec/rails_helper.rb` via `config.include FactoryBot::Syntax::Methods`.

**CI pipeline** (`.github/workflows/ci.yml`) runs: Brakeman, bundler-audit, importmap audit, RuboCop, unit tests, and system tests — all must pass before merging.
