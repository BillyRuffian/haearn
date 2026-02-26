# AGENTS.md - Haearn Project Context

> **Haearn** = "Iron" in Welsh 🏴󠁧󠁢󠁷󠁬󠁳󠁿

## Instructions for AI Agents

1. **Read this file first** at the start of every session
2. **Read `docs/PLAN.md`** to understand the implementation roadmap and current progress
3. **Keep `docs/PLAN.md` up to date** — this is critical:
   - Check off completed items (`- [x]`) immediately after implementing them
   - Add new items when the user requests features not yet in the plan
   - Move or re-prioritize items when the user changes direction
   - Update the "Last Updated" date at the top when making changes
4. **Update this file (AGENTS.md)** when:
   - The user makes a design decision that affects future work
   - New patterns or conventions are established
   - Technical choices are made that should be remembered
5. **Ask clarifying questions** before implementing if requirements are unclear

## Project Overview

Haearn is a **hardcore weightlifting tracking application** built with Ruby on Rails 8. It's designed for serious lifters who need granular control over their workout data, including tracking specific machines, cable pulley ratios, and detailed progress metrics.

## Critical Commands

```bash
# Start development server (REQUIRED - uses foreman for CSS compilation)
bin/dev

# DO NOT USE rails server directly - CSS won't compile
# ❌ rails server
# ❌ rails s
```

## Tech Stack

- **Ruby on Rails 8** (latest)
- **SQLite** for development (Rails 8 default)
- **Rails 8 Authentication** - NOT Devise (use `rails generate authentication`)
- **Hotwire** (Turbo + Stimulus) - make it feel like a native app
- **Bootstrap 5** - with heavy custom dark/moody styling
- **PWA** - runs from phone home screen, offline support via Service Worker
- **Importmaps** - no Node.js bundling for JS

## Design Philosophy

### Visual Theme: Dark & Moody Iron
- Dark backgrounds (#1a1a1a, #121212)
- Iron/steel accent colors (gunmetal grays, rust oranges) and gradients
- Industrial typography
- Minimal, functional UI - no fluff
- Mobile-first design

### UX Philosophy
- **Fast**: Turbo Frames/Streams everywhere, minimal full page loads
- **Efficient**: Fewest taps possible to log a set
- **Informative**: Always show last workout's numbers
- **Offline-capable**: Service worker caches app shell, syncs when online

### JavaScript Philosophy
- **Always use Stimulus controllers** for client-side behavior
- Never write inline JavaScript or standalone JS files
- Stimulus controllers live in `app/javascript/controllers/`
- Use data attributes to connect HTML to controllers

## Data Model Summary

### Core Entities

```
User
├── preferred_unit (kg/lbs)
├── Gyms (user defines their own)
│   └── Machines (specific equipment at each gym)
│       ├── equipment_type (barbell, dumbbell, machine, cables, etc.)
│       ├── weight_ratio (for cable pulleys, e.g., 0.5 for 2:1)
│       └── display_unit (what the machine shows)
│
├── Workouts (individual sessions)
│   ├── gym_id
│   ├── notes (overall session notes)
│   ├── started_at / finished_at
│   │
│   └── WorkoutBlocks (groups exercises, enables supersets)
│       ├── position (ordering)
│       ├── rest_seconds
│       │
│       └── WorkoutExercises (exercises in this block)
│           ├── exercise_id
│           ├── machine_id (optional)
│           ├── session_notes ("felt weak today")
│           ├── persistent_notes ("seat at position 3")
│           │
│           └── Sets
│               ├── is_warmup (boolean)
│               ├── weight_kg (normalized to kg internally)
│               ├── reps / duration_seconds / distance_meters
│               └── completed_at
│
└── Exercises (library)
    ├── user_id (null = global/seeded)
    ├── exercise_type (reps, time, distance)
    └── has_weight (boolean)
```

### Key Design Decisions

1. **Weight Normalization**: All weights stored in kg internally. Convert to/from user's preferred unit on display/input.

2. **Blocks for Everything**: Even single exercises are a block with one exercise. This unifies the model for normal sets, supersets, and circuits.

3. **Superset Pattern**: Block A might have [Bench Press, Bent Row]. User does: A1 set 1, A2 set 1, A1 set 2, A2 set 2, etc.

4. **Machine-Specific Tracking**: Same exercise on different machines is tracked separately. PRs are per exercise AND per machine.

5. **Three Notes Levels**:
   - `Workout.notes` - "Cold day, felt stiff"
   - `WorkoutExercise.session_notes` - "Shoulder twinge on set 3"
   - `WorkoutExercise.persistent_notes` - "Use handle B, seat at 4"

6. **PR Scope Includes Equipment State**: PRs can be tracked separately as raw vs equipped, where "equipped" means any set using belt, knee sleeves, wrist wraps, or straps.

7. **Performance Notifications Pattern**: Analytics alerts are persisted in `notifications` and surfaced dynamically via JSON polling (`/notifications/feed`) with Stimulus (`notifications_center_controller`) in navbar + dashboard. Rest timer completion should also persist to this same notification feed (`/notifications/rest_timer_expired`) so browser push and in-app notifications stay consistent. Alert generation/display must honor user notification preferences from Settings.

8. **Dashboard Information Architecture**: Keep `dashboard#index` focused on overview/quick actions and place charts in `dashboard#analytics` (accessible from desktop nav and mobile bottom nav).

9. **Analytics Query Pattern**: For week-based dashboard analytics, use grouped SQL week buckets (SQLite `strftime`) plus Ruby gap-filling instead of issuing one query per week; preload lookup tables (exercise/machine) before loops to avoid N+1.

10. **Analytics/Admin Index Baseline**: Maintain indexes for time-window analytics and admin counters (`workouts(user_id, finished_at)`, `users.created_at`, `users.updated_at`, `workouts.created_at`) before adding new chart/counter queries.

11. **Dashboard Analytics Caching**: Expensive dashboard analytics datasets should use user-scoped short-TTL `Rails.cache` entries; keep active workout and readiness checks uncached for near-real-time feedback.
    Invalidate dashboard analytics cache after commits that affect analytics inputs (`Workout`, `WorkoutExercise`, `ExerciseSet`) using `DashboardAnalyticsCache.invalidate_for_user!`.
    Cache invalidation is deduped per request/context via `Current` tracking to avoid repeated version bumps during bulk set/exercise updates.
    Cache keys are chart-scoped and include per-user per-chart version tokens (`...:version:n`) so invalidation can target only affected charts without broad deletes.
    Prefer scoped invalidation keys per model/change type so non-impacting updates (e.g., notes-only edits) do not clear unrelated analytics caches.

12. **Mobile Calendar Density Rule**: On small screens, calendar cells should prioritize glanceability by showing activity color intensity + workout-count badge only; hide per-day volume/set text and workout-dot clusters.

13. **Performance Alert Guardrails**: Volume-drop alerts should compare week-to-date volume against the same elapsed portion of last week and should not fire before any workout is logged in the current week. Fatigue analysis baselines must stay scoped to the exact exercise + machine combination.

14. **Calendar Activity Tiering**: Calendar activity coloring should use explicit tiers by workout count (1/2/3/4+) with progressively stronger cell backgrounds and badge contrast, optimized for quick mobile glanceability.

15. **Web Push Delivery Pipeline**: Browser push uses persisted `PushSubscription` records per user and VAPID configuration (`VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` or `credentials.web_push.*`). Deliver pushes from persisted `Notification` records via `WebPushNotificationService`, and auto-prune expired/invalid subscriptions on push errors.

16. **Analytics Cache Observability**: Dashboard analytics cache must emit per-user daily counters (`cache_hit`, `cache_miss`, `invalidation`) and `ActiveSupport::Notifications` events (`dashboard_analytics_cache.fetch`, `dashboard_analytics_cache.invalidate`) so hit-rate regressions are visible.

17. **Web Push Observability**: Push delivery telemetry should be tracked in `WebPushNotificationService` as counters for attempts/successes/failures, bucketed by endpoint host and failure error class, with simple query/reset helpers for operational checks and tests.

18. **Web Push Retry Policy**: Retry only transient push failures (timeouts/network interruptions, 429, 5xx/push-service errors) with exponential backoff; do not retry permanent subscription errors (`ExpiredSubscription`/`InvalidSubscription`) and continue pruning invalid subscriptions.

19. **Push Subscription Health**: Track per-device delivery health on `PushSubscription.last_successful_push_at`; surface user-facing health indicators as subscribed device count + most recent successful push timestamp.

20. **Offline Confidence UX**: Keep a persistent, glanceable sync-confidence widget driven by `offline_controller` showing state (`Offline`/`Syncing`/`Sync failed`/`Synced`), queued action count, last synced time, and a manual retry trigger.

21. **Quick Log Mode**: Active workout pages can switch into a one-thumb Quick Log mode (query-param driven) that prioritizes primary set inputs and single-tap logging, while preserving full mode for RPE/RIR/warmup details.

22. **Machine Setup Memory**: Store personal setup defaults on `Machine` (`seat_setting`, `pin_setting`, `handle_setting`) and surface the combined setup summary in workout logging context.

23. **Plate Sanity Warnings**: Plate calculator should display inline warnings for impossible/impractical targets (below bar weight, uneven side loading, excessive plate count per side, non-exact combinations) instead of silently failing.

24. **Machine Unit Default & Input Rule**: New machines should default `display_unit` to the creating user's `preferred_unit`. For set entry, when a machine has `display_unit`, UI labels/placeholders/input hints must use that machine unit; otherwise use user preferred unit.

25. **Regression Testing Direction**: For new regression coverage, prefer RSpec over Minitest. Keep high-risk UI behavior checks in focused request/helper specs (with fixture-backed deterministic setup), and extend this suite whenever regressions are fixed.

26. **Core Safety Net Baseline**: Keep a small RSpec request-suite that always covers core user flows (auth gating, workout lifecycle, settings updates), push endpoints (subscription + rest-timer dedupe), and admin audit-log access/filtering to catch high-impact regressions early.

27. **Progression Messaging Timing**: Do not show progression prompts during active set entry. Aggregate and show progression updates together on completed workout pages so logging flow stays uncluttered.

## Equipment Types (Enum)

```ruby
EQUIPMENT_TYPES = %w[
  barbell
  dumbbell
  machine
  cables
  bodyweight
  kettlebell
  bands
  smith_machine
  other
].freeze
```

## Exercise Types (Enum)

```ruby
EXERCISE_TYPES = %w[
  reps      # counted repetitions (most exercises)
  time      # duration-based (planks, hangs)
  distance  # distance-based (farmer's walks, sled push)
].freeze
```

## Features by Priority

### Phase 1: Foundation
- [ ] Rails 8 authentication (users)
- [ ] Exercise library (seeded + custom)
- [ ] Gyms & Machines CRUD
- [ ] Basic workout logging
- [ ] Dark theme styling

### Phase 2: Core Workout Experience
- [ ] Workout blocks & supersets
- [ ] Set logging with warmup marking
- [ ] Rest timer (Stimulus controller)
- [ ] Previous workout display
- [ ] Turbo Frames for smooth UX

### Phase 3: Progress & History
- [ ] Personal Records tracking
- [ ] Volume calculations
- [ ] Progress charts (Chart.js or similar)
- [ ] Workout history per exercise/machine
- [ ] Copy past workouts

### Phase 4: PWA & Offline
- [ ] Service worker for app shell caching
- [ ] IndexedDB for offline workout storage
- [ ] Background sync when online
- [ ] Home screen installability

### Phase 5: Polish
- [ ] Data export (CSV/JSON)
- [ ] Workout templates/programs
- [ ] Advanced analytics

## Testing

```bash
# Run all tests
rails test

# Run system tests
rails test:system
```

## Liniting

Make sure the code linter passes

```bash
# Run Rubocop
bundle exec rubocop -A
```

## Performance Baseline

```bash
# Dashboard/notification timing baseline (supports USER_ID, RUNS, WARMUP)
bin/rails performance:benchmark_dashboard RUNS=10 WARMUP=2
```

## Web Push Setup

```bash
# Generate OpenSSL 3-compatible VAPID keys for web push
bin/rails web_push:generate_keys
```

## Common Patterns

### Turbo Frame for inline editing
```erb
<%= turbo_frame_tag dom_id(set) do %>
  <!-- set display, click to edit -->
<% end %>
```

### Turbo Stream for real-time updates
```ruby
respond_to do |format|
  format.turbo_stream
  format.html { redirect_to workout_path(@workout) }
end
```

### Stimulus for client-side behavior
```javascript
// app/javascript/controllers/rest_timer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Timer logic:
  // - Default countdown (configurable per exercise, e.g., 90s)
  // - Skip button to dismiss immediately
  // - +15s / -15s buttons to adjust on the fly
  // - Auto-starts after logging a set
  // - Audio/vibration alert when complete
}
```

## File Locations

- Controllers: `app/controllers/`
- Models: `app/models/`
- Views: `app/views/`
- Stimulus Controllers: `app/javascript/controllers/`
- Stylesheets: `app/assets/stylesheets/`
- Tests: `test/`

## Remember

1. Always use `bin/dev` to run the server
2. Mobile-first, dark theme
3. Turbo everything - minimize full page loads
4. Store weights in kg, display in user preference
5. This is for serious lifters - no dumbing down the features
