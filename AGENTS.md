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
