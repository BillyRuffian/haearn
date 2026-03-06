# Haearn

Haearn is a serious weightlifting tracker built with Rails 8 for lifters who care about exact machine setup, normalized weight data, supersets, progression signals, and a fast mobile logging flow.

The app is opinionated in a few important ways:

- weights are stored in kg internally and converted at the edges
- workout blocks are the core abstraction for both single exercises and supersets
- machine-specific history matters, so the same exercise on different machines is treated differently
- the app is designed as a mobile-first PWA, not just a desktop CRUD app

## Stack

- Ruby on Rails 8
- SQLite in development and test
- Rails authentication generated with `rails generate authentication`
- Hotwire: Turbo + Stimulus
- Importmap for JavaScript
- Bootstrap 5 with a custom industrial dark theme
- Solid Cache, Solid Queue, and Solid Cable
- Active Storage for machine and progress photos
- Web Push for persisted notification delivery

## Getting Started

### Prerequisites

- Ruby matching the project toolchain
- Bundler
- Node/Yarn for CSS compilation
- SQLite

### Initial Setup

```bash
bin/setup
```

That will:

- install Ruby dependencies
- install JavaScript dependencies
- prepare the database
- clear logs and temp files
- start the development environment unless `--skip-server` is passed

### Running the App

Use:

```bash
bin/dev
```

Do not use `rails server` directly for normal development. The app depends on the CSS watcher defined in [Procfile.dev](/home/nbt/Projects/Haearn/Procfile.dev).

### Core Commands

```bash
# Start app + CSS watcher
bin/dev

# Prepare local databases
bin/rails db:prepare

# Reset local data
bin/setup --reset

# Run focused Rails tests
bin/rails test test/controllers/dashboard_controller_test.rb

# Run focused RSpec tests
bundle exec rspec spec/requests/workout_ui_regressions_spec.rb

# Run RuboCop autofix
bundle exec rubocop -A

# Dashboard benchmark
bin/rails performance:benchmark_dashboard RUNS=10 WARMUP=2

# Generate VAPID keys for web push
bin/rails web_push:generate_keys
```

## Project Structure

### Important Directories

- `app/controllers/`: request orchestration
- `app/models/`: core domain entities
- `app/services/`: business logic, analytics, notifications, conversion, caching
- `app/views/`: Turbo-first server-rendered UI
- `app/javascript/controllers/`: Stimulus controllers
- `app/assets/stylesheets/`: Bootstrap theme and custom styling
- `spec/`: preferred location for new regression coverage
- `test/`: existing Minitest coverage, especially for Rails-layer behavior
- `docs/PLAN.md`: active roadmap and refactor checklist
- `AGENTS.md`: long-lived project conventions and decisions

### Key Entry Points

- root dashboard: [dashboard_controller.rb](/home/nbt/Projects/Haearn/app/controllers/dashboard_controller.rb)
- workout flow: [workouts_controller.rb](/home/nbt/Projects/Haearn/app/controllers/workouts_controller.rb)
- set logging: [exercise_sets_controller.rb](/home/nbt/Projects/Haearn/app/controllers/exercise_sets_controller.rb)
- dashboard page assembly: [dashboard_page_data_builder.rb](/home/nbt/Projects/Haearn/app/services/dashboard_page_data_builder.rb)
- dashboard analytics calculations: [dashboard_analytics_calculator.rb](/home/nbt/Projects/Haearn/app/services/dashboard_analytics_calculator.rb)
- analytics caching: [dashboard_analytics_cache.rb](/home/nbt/Projects/Haearn/app/services/dashboard_analytics_cache.rb)
- notifications: [performance_notification_service.rb](/home/nbt/Projects/Haearn/app/services/performance_notification_service.rb)
- push delivery: [web_push_notification_service.rb](/home/nbt/Projects/Haearn/app/services/web_push_notification_service.rb)

## Core Domain Model

The main relational flow is:

```text
User
  -> Gyms
    -> Machines
  -> Workouts
    -> WorkoutBlocks
      -> WorkoutExercises
        -> ExerciseSets
  -> WorkoutTemplates
  -> BodyMetrics
  -> ProgressPhotos
  -> Notifications
  -> PushSubscriptions
```

### Important Concepts

#### Weight Normalization

- `ExerciseSet.weight_kg` is the canonical stored value
- UI input/display can use the user preferred unit or the machine display unit
- machine pulley ratios are handled during conversion, not in reporting

#### Workout Blocks

- every exercise is inside a `WorkoutBlock`
- one exercise in a block = normal exercise
- multiple exercises in a block = superset/circuit

#### Machine-Specific Tracking

- progress is scoped to exercise plus machine where applicable
- setup memory like seat/pin/handle settings lives on `Machine`

#### Persisted Notifications

- readiness, plateau, streak-risk, volume-drop, and rest timer notifications are saved in the database
- in-app notifications and browser push use the same persisted notification records

## Main User Flows

### Workout Logging

1. Start a workout from the dashboard or a pinned template
2. Choose a gym
3. Add exercises, optionally attaching them to a specific machine
4. Log sets inline with Turbo Streams
5. Let the rest timer auto-start after each logged set
6. Finish the workout and view progression suggestions on the completed workout page

### Exercise History

- each exercise has a history view
- machine filters matter
- PRs are calculated on demand, not stored in a separate model

### Dashboard / Analytics

- the dashboard overview mixes live status with cached analytics
- expensive analytics are short-TTL cached per user and invalidated by workout-related changes
- page assembly and chart calculations are now separated into service objects

## Frontend Conventions

- use Stimulus for client-side behavior
- avoid inline JavaScript
- prefer Turbo Frames and Turbo Streams over bespoke API-driven UI
- treat the mobile workout screen as the highest-priority UX
- add and edit set UIs should stay aligned through shared view partials in `app/views/exercise_sets/`

## Testing

The app currently uses both Minitest and RSpec.

### Where to Add New Tests

- prefer RSpec for new regression coverage
- keep high-risk UI regressions in focused request specs
- keep service logic in service specs/tests
- keep Rails integration behavior in existing Minitest areas when extending those files is the lowest-friction path

### Useful Suites

```bash
# Core request safety net
bundle exec rspec spec/requests/core_functionality_spec.rb

# Workout UI regressions
bundle exec rspec spec/requests/workout_ui_regressions_spec.rb

# Notifications and push
bundle exec rspec spec/requests/notifications_and_push_spec.rb

# Dashboard controller smoke tests
bin/rails test test/controllers/dashboard_controller_test.rb
```

Note: because test uses SQLite, running multiple spec processes in parallel can cause `database is locked` failures. Sequential runs are safer unless the test environment is changed.

## Background Jobs, Cache, and Scheduling

- development/test use SQLite-backed defaults from [config/database.yml](/home/nbt/Projects/Haearn/config/database.yml)
- production splits primary, cache, queue, and cable databases
- Solid Queue configuration lives in [config/queue.yml](/home/nbt/Projects/Haearn/config/queue.yml)
- cache configuration lives in [config/cache.yml](/home/nbt/Projects/Haearn/config/cache.yml)
- recurring production jobs live in [config/recurring.yml](/home/nbt/Projects/Haearn/config/recurring.yml)

Current recurring production jobs include:

- weekly summary email delivery
- audit-log cleanup
- Solid Queue finished-job cleanup

## PWA and Offline Notes

- the app ships a manifest and service worker
- offline queueing is handled via IndexedDB plus Stimulus controllers
- sync confidence is surfaced in the navbar
- push subscriptions are stored per user/device

Relevant files:

- [manifest.json.erb](/home/nbt/Projects/Haearn/app/views/pwa/manifest.json.erb)
- [service-worker.js](/home/nbt/Projects/Haearn/app/views/pwa/service-worker.js)
- [offline_controller.js](/home/nbt/Projects/Haearn/app/javascript/controllers/offline_controller.js)
- [offline_form_controller.js](/home/nbt/Projects/Haearn/app/javascript/controllers/offline_form_controller.js)

## Development Guidelines

- read [AGENTS.md](/home/nbt/Projects/Haearn/AGENTS.md) first for project rules
- keep [docs/PLAN.md](/home/nbt/Projects/Haearn/docs/PLAN.md) updated when work completes or scope changes
- preserve the industrial dark visual language
- prefer service objects for non-trivial workflow or analytics logic
- keep `DashboardController` thin and put analytics calculations in service objects
- preserve machine-aware unit conversion behavior whenever changing set logging or display

## Known Gaps / Next Improvements

The active improvement track in [docs/PLAN.md](/home/nbt/Projects/Haearn/docs/PLAN.md) currently focuses on:

- frontend behavior coverage for critical Stimulus flows
- contributor/onboarding improvements
- further analytics/query cleanup

