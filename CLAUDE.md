# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Haearn ("Iron" in Welsh) is a weightlifting tracking PWA built with Ruby on Rails 8. It targets serious lifters who need granular control: machine-specific tracking, cable pulley weight ratios, supersets via workout blocks, RPE/RIR logging, and detailed progress analytics.

Also read `AGENTS.md` for design decisions and data model details, and `docs/PLAN.md` for the implementation roadmap.

## Development Commands

```bash
# Start dev server (REQUIRED - runs Rails + CSS watcher via foreman)
bin/dev

# DO NOT use `rails server` or `rails s` directly - CSS won't compile

# Run all tests
rails test

# Run system tests (Capybara + Selenium)
rails test:system

# Run a single test file
rails test test/models/workout_test.rb

# Run a single test by line number
rails test test/models/workout_test.rb:42

# Lint and auto-fix Ruby code
bundle exec rubocop -A

# Compile CSS once (normally handled by bin/dev)
yarn build:css
```

## Tech Stack

- **Ruby 4.0.1 / Rails 8.1.2** with SQLite3
- **Hotwire** (Turbo + Stimulus) via importmaps -- no JS bundler
- **Bootstrap 5** with heavily customized dark SCSS theme
- **Propshaft** asset pipeline, **cssbundling-rails** for SCSS compilation
- **Rails 8 built-in authentication** (NOT Devise) -- `has_secure_password`, `Session` model, signed cookies
- **Solid Queue/Cache/Cable** -- all SQLite-backed, queue runs in-process via Puma
- **Kamal** for Docker deployment to production (www.haearn.com)

## Architecture

### Data Model (key relationships)

```
User → Gyms → Machines (equipment_type, weight_ratio for cables)
User → Workouts → WorkoutBlocks → WorkoutExercises → ExerciseSets
User → WorkoutTemplates → TemplateBlocks → TemplateExercises
User → BodyMetrics
Exercises (user_id NULL = global seeded, non-null = user custom)
```

**Blocks are the grouping primitive**: even a single exercise lives in a block. Multiple exercises in one block = superset. This is the core structural pattern.

**Exercise types** determine which fields are relevant on a set: `reps` (most exercises), `time` (planks, hangs → `duration_seconds`), `distance` (farmer's walks → `distance_meters`). The `has_weight` boolean controls whether weight input is shown.

**Three notes levels**: `Workout.notes` (session-level), `WorkoutExercise.session_notes` (per-exercise, one-off), `WorkoutExercise.persistent_notes` (per-exercise, auto-copied from previous workout -- e.g., "seat at position 4").

### Weight Handling

All weights are **stored in kg** (`weight_kg` columns). Conversion to/from the user's `preferred_unit` (kg or lbs) happens at display/input time. The `WeightConverter` service handles all conversions including machine weight ratios (e.g., 2:1 cable pulleys where `weight_ratio = 0.5`).

### Request/Response Pattern

Controllers respond with both HTML and **Turbo Stream** formats. Most CRUD operations use Turbo Frames for inline editing and Turbo Streams for real-time updates. Minimize full page reloads.

```ruby
respond_to do |format|
  format.turbo_stream
  format.html { redirect_to ... }
end
```

### JavaScript

All client-side behavior uses **Stimulus controllers** (`app/javascript/controllers/`). No inline JS. External libraries loaded via importmap: Chart.js 4.4.0, SortableJS 1.15.0, Bootstrap from CDN.

### Service Objects (`app/services/`)

Business logic lives in service objects, not models:
- `WeightConverter` -- unit conversion with machine ratio support
- `PrCalculator` -- personal record detection (weight, volume, session)
- `OneRmCalculator` -- estimated 1RM from submaximal sets
- `ProgressionSuggester` -- auto-suggests weight increases based on RPE/RIR trends
- `ProgressionReadinessChecker` -- detects readiness to increase weight
- `FatigueAnalyzer` -- compares current session to rolling baseline
- `WilksCalculator` -- powerlifting strength scoring
- `WarmupGenerator` -- auto-generates warmup set progression
- `WeeklySummaryCalculator` -- stats for weekly email digest

### Authentication

Rails 8 built-in auth via `Authentication` concern. `Current.user` gives the logged-in user. Controllers use `before_action :require_authentication` (inherited from ApplicationController) and `allow_unauthenticated_access` for public routes.

### PWA / Offline

Service worker caches the app shell. `offline_form_controller.js` queues forms to IndexedDB when offline and syncs on reconnection. `wake_lock_controller.js` prevents screen sleep during workouts.

## Code Style

- **Rubocop** with `rubocop-rails-omakase` preset
- **Single quotes** for Ruby strings (no interpolation)
- Mobile-first, dark theme (backgrounds #0a0a0a-#1e1e1e, rust/orange accents, industrial typography)
- SCSS lives in `app/assets/stylesheets/application.bootstrap.scss`
