# AGENTS.md

Chewy is an open-source Elasticsearch ODM for Ruby, published to rubygems.org as `chewy`.
Read `README.md` and `CONTRIBUTING.md` first.

## Commands

```sh
docker compose up elasticsearch_test -d  # Elasticsearch on localhost:9250 for the specs
bundle exec rspec                        # all specs
bundle exec rspec spec/path/to_spec.rb   # one file; add :LINE for one example
BUNDLE_GEMFILE=gemfiles/rails.8.0.activerecord.gemfile bundle exec rspec  # specs with one Rails version
bundle exec rubocop                      # lint
```

CI (`.github/workflows/ruby.yml`) runs the specs for each Ruby and Rails pair, and RuboCop.
The `Plumber` workflow checks the security of the workflows.
Make all of them pass before a merge.

## Never do this

- Do not point `ES_HOST` or `ES_PORT` at a cluster with data you need.
  The specs delete all indices that do not start with `.`.
- Do not run `bundle exec rake release` or `gem push`, and do not push tags.
  A maintainer releases the gem.

## Public API and releases

- The public API is what `README.md` and `docs/` describe: the index DSL, update strategies, the query DSL, the rake tasks and the RSpec and Minitest helpers.
- Chewy does not follow semver.
  The major version follows the newest supported Elasticsearch version, and a minor version can contain breaking changes.
- Add each user-visible change under `## master (unreleased)` in `CHANGELOG.md`, in the format that `CONTRIBUTING.md` gives.
  Mark a breaking change `**(Breaking)**`.
- Put upgrade steps for a new major version in `migration_guide.md`.
- Do not change `lib/chewy/version.rb` or the `Rakefile`.
  A maintainer bumps the version in a release PR.

## Architecture

- `lib/chewy/index/` holds the index DSL, `lib/chewy/search/` the query DSL, and `lib/chewy/strategy/` the update strategies.
- `lib/chewy.rb` requires each file explicitly.
- `docs/README.md` lists the user guides.
  Update the guide that describes a feature when you change it.

## Configuration and secrets

- Apps configure the gem through `Chewy.settings` or `config/chewy.yml` (see `docs/configuration.md`).
- `spec/spec_helper.rb` sets the test settings and reads `ES_HOST` and `ES_PORT`.
- Never commit real Elasticsearch credentials.

## Tests

- The specs need Elasticsearch on port 9250.
- The `delayed_sidekiq` specs also need Redis on port 6379 (`redis_test` in `docker-compose.yml`).
- ActiveRecord uses SQLite in memory.

## Dependencies

- CI tests Ruby 3.2, 3.3, 3.4 and 4.0, each with the Rails 7.2, 8.0 and 8.1 gemfiles in `gemfiles/`.
- The gemspec allows Ruby `>= 3.2` and `elasticsearch` `>= 8.14, < 9.0`.

## Evidence

- Give the output of the focused specs and RuboCop at the current commit.
- This repo has no E2E suite.
  Capture no artifacts.

## Protected paths

Get a person's approval before you change `lib/chewy/version.rb`, `chewy.gemspec`, `Rakefile`, `.github/`, `gemfiles/` or `AGENTS.md`.
Pin each GitHub Action to a commit SHA, as `.github/workflows/ruby.yml` does.
