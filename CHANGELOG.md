# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.2] - 2026-06-16

### Fixed
- `today_enabled_configs` now returns a proper `UMS::GentleNudge::Configs` resultset instead of a broken hashref
- Fixed filtering: method now filters on both `enabled` and `day_of_week` (previously used non-existent `run_on_dow` column)
- Callers use `$self->configs->today_enabled_configs` factory method instead of direct class calls
- Fixed fat comma (`=>`) used instead of assignment (`=`) in cronjob caller
- Fixed `foreach` on scalar replaced with proper `->next` iteration
- Replaced hashref field access (`$config->{field}`) with object accessors (`$config->field`)
- Removed stale `warn` statements from production code

### Added
- Unit tests for `today_enabled_configs` with deterministic date mocking

## [0.7.1] - 2026-06-08

### Fixed
- CI: Add `permissions` block to workflow to fix publish-test-results 403 after repo transfer (#21)
- CI: Add missing `devDependencies` (gulp, vinyl) for kpz build step (#21)

## [0.7.0] - 2026-06-08

### Fixed
- Schema Result column mismatch: renamed `debit_type` to `config_debit_type` to match actual DB column (#22)
- Removed duplicate `require_lost` column declaration in Schema Result
- CI test failures caused by Unknown column 'debit_type' in INSERT

### Changed
- Normalized `debit_types` and `patron_categories` from JSON VARCHAR columns into proper join tables (#23)
- API input now uses `debit_type_codes` and `patron_category_codes` (arrays of strings)
- API output embeds full `Koha::Account::DebitTypes` and `Koha::Patron::Categories` objects via `x-koha-embed`
- ConfigController uses `set_debit_types`/`set_patron_categories` methods instead of raw DBIC calls
- OpenAPI spec: `x-koha-embed` defined as proper header parameter with enum
- JS updated to use new field names and embed header on edit form load

### Added
- Join tables `config_dt` and `config_pc` with real FKs to `account_debit_types` and `categories`
- Schema Result classes for link tables with `belongs_to` relationships
- `debit_types()`, `patron_categories()`, `set_debit_types()`, `set_patron_categories()`, `add_debit_type()`, `add_patron_category()` methods on `UMS::GentleNudge::Config`
- Schema source registration in plugin BEGIN block for Plack compatibility
- Legacy field name support (`debit_type`, `patron_categories`) for backward compatibility
- Project badges in README (#26)