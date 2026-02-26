# Haearn Implementation Plan

> Last Updated: February 26, 2026

## Overview

This document outlines the phased implementation of Haearn, a hardcore weightlifting tracking application.

---

## Phase 1: Foundation & Authentication

### 1.1 Authentication Setup
- [x] Run `rails generate authentication`
- [x] Add user profile fields:
  - `preferred_unit` (string, default: 'kg')
  - `name` (string)
- [x] Create registration flow
- [x] Style login/register pages (dark theme)
- [x] Add current user helper methods

### 1.2 Database Schema - Core Models
- [x] Gym model with user association
- [x] Exercise model with types (reps/time/distance)
- [x] Machine model with equipment types and weight ratio
- [x] Workout model with blocks
- [x] WorkoutBlock model for supersets
- [x] WorkoutExercise with session/persistent notes
- [x] ExerciseSet with warmup flag

### 1.3 Exercise Seeds
- [x] Create `db/seeds/exercises.rb` with common exercises:
  - Compound lifts (Bench, Squat, Deadlift, OHP, Row)
  - Isolation exercises (Curls, Tricep extensions, etc.)
  - Cable exercises
  - Machine exercises
  - Bodyweight exercises
  - Time-based (Planks, Dead hangs)
  - Distance-based (Farmer's walks)
- [x] 103 exercises seeded

### 1.4 Dark Theme Styling
- [x] Create custom Bootstrap variables in `application.bootstrap.scss`:
  - Dark background colors
  - Iron/rust accent colors
  - Custom component styling
- [x] Create base layout with:
  - Dark navbar
  - Mobile-optimized navigation
  - Footer with app info

---

## Phase 2: Gyms & Machines CRUD

### 2.1 Gyms
- [x] `GymsController` with full CRUD
- [x] Turbo Frame for inline editing
- [x] Mobile-friendly list/card views
- [x] Quick-add form

### 2.2 Machines
- [x] `MachinesController` (nested under gyms)
- [x] Equipment type selector
- [x] Weight ratio input for cables
- [x] Display unit selector
- [x] Persistent notes field

### 2.3 Machine Photos
- [x] Active Storage setup (local disk storage, not cloud)
- [x] Multiple photos per machine (gallery)
- [x] Camera capture directly from mobile (not just file picker)
- [x] Photo use cases:
  - Machine identification (which leg press is this?)
  - Seat/pad position settings
  - Pin placement for adjustments
  - Cable attachment setup
  - Weight stack/plate configuration
- [x] Photo thumbnails on machine list
- [x] Full-screen photo viewer with swipe
- [x] Delete/reorder photos
- [ ] Optional: annotate photos (draw circles/arrows on settings)

### 2.4 Exercise Library
- [x] `ExercisesController` for viewing/creating
- [x] Filter by type (reps/time/distance)
- [x] Search functionality
- [x] Mark user-created vs global exercises
- [x] Search-as-you-type with instant results

---

## Phase 3: Workout Logging (Core Feature)

### 3.1 Start/End Workout
- [x] "Start Workout" button on dashboard
- [x] Select gym
- [x] Create Workout record with `started_at`
- [x] Active workout indicator in navbar
- [x] "Finish Workout" sets `finished_at`
- [x] Workout timer showing elapsed time

### 3.2 Adding Exercises to Workout
- [x] Exercise picker (search + modal)
- [x] Create WorkoutBlock + WorkoutExercise
- [x] Optional machine selection (filtered by gym)
- [x] Show persistent notes from last time

### 3.3 Superset/Circuit Support
- [x] "Add to Block" vs "New Block" options
- [x] Visual grouping of block exercises
- [x] Block ordering (drag & drop)

### 3.4 Set Logging
- [x] Quick-add set form
- [x] Weight input with unit conversion
- [x] Reps/Time/Distance based on exercise type
- [x] Warmup checkbox
- [x] Show previous workout's sets for reference
- [x] Turbo Stream for instant feedback
- [x] "+1 Rep" quick button from previous set
- [x] Show progression updates as a grouped summary after workout completion (not during active set entry)

### 3.5 Rest Timer (Stimulus)
- [x] `rest_timer_controller.js`
- [x] Default countdown timer (configurable, saved to localStorage)
- [x] Skip button to dismiss immediately
- [x] +15s / -15s adjustment buttons
- [x] Audio/vibration alert when complete
- [x] Auto-start after logging a set
- [x] Visible countdown in UI
- [x] Remember last-used duration per exercise
- [x] Floating action button to manually start

### 3.6 Notes
- [x] Overall workout notes field

### 3.7 Barbell Plate Calculator
- [x] `plate_calculator_controller.js` Stimulus controller
- [x] Show plate breakdown for barbell exercises
- [x] Visual bar/plate graphic representation:
  - Bar assumed to be 20kg (kg) or 45lbs (lbs)
  - Standard Olympic plate colors (Red=25kg, Blue=20kg, Yellow=15kg, Green=10kg, White=5kg, etc.)
  - Plates sized proportionally to weight
  - Show one side of the bar (plates are symmetric)
- [x] Calculate optimal plate combination for target weight
- [x] Display below weight input on set form for barbell machines
- [x] Per-exercise session notes display
- [x] Per-exercise persistent notes (copied from previous workout)

---

## Phase 4: History & Progress

### 4.1 Workout History
- [x] List all past workouts
- [x] Filter by gym, date range
- [x] Workout detail view
- [x] Copy workout (duplicate to new session)
- [x] Edit historical workouts (metadata, exercises, sets)
- [x] Continue recently finished workouts (within 1 hour)
- [x] Muscle group badges on workout cards

### 4.2 Exercise History
- [x] View all sessions for an exercise
- [x] Filter by machine (tabs)
- [x] Show sets, weights, volume

### 4.3 Personal Records
- [x] Calculated PRs (no separate model needed)
- [x] Track PRs per exercise (displayed on history page)
- [x] PR types:
  - Heaviest set (weight)
  - Best single set volume (weight × reps)
  - Best session volume
- [x] PR badges/highlights in history

### 4.4 Progress Charts
- [x] Integrate Chart.js via importmap
- [x] Weight progression over time
- [x] Volume over time
- [x] Workout frequency (8-week bar chart on dashboard)

### 4.5 Advanced Visualizations (Future)
- [x] **Workout Consistency Visualization** - Last 12 weeks bar chart + day-of-week pattern (replaced GitHub-style heatmap)
- [x] **PR Timeline** - Scatter plot showing when PRs were hit across all lifts
- [x] **Estimated 1RM Trend** - Track e1RM over time (more meaningful than raw weight)
- [ ] **Volume Distribution Pie Chart** - Breakdown by muscle group (weekly/monthly)
- [ ] **Lift Ratio Spider Chart** - Balance between major lifts (squat/bench/deadlift/OHP)
- [x] **Rep Range Distribution** - Bar chart showing % of sets in each rep range (1-5, 6-10, 10+)
- [x] **Training Density** - Volume per minute/hour over time (workout efficiency)
- [x] **Tonnage Tracker** - Total weight lifted per session/week/month (area chart)
- [ ] **Strength Curve** - Performance at different rep ranges per exercise (are you better at 3s or 10s?)
- [x] **Session Duration Trends** - Are workouts getting longer/shorter?
- [x] **Body Map Heatmap** - Visual showing which muscles trained recently (recovery indicator)
- [x] **Exercise Frequency Ranking** - Bar chart of most-performed exercises
- [x] **Consistency Streaks** - Current/longest streak visualizations
- [x] **Week-over-Week Comparison** - Side-by-side volume bars for this week vs last
- [ ] **Wilks/DOTS Score Over Time** - For powerlifters tracking relative strength
- [x] **Plateau Detector** - Visual highlighting exercises with no PR in X weeks
- [ ] **Training Split Adherence** - Planned vs actual sessions (donut chart)

---

## Phase 5: Unit Conversion System

### 5.1 Weight Conversion Module
- [x] `WeightConverter` service object (`app/services/weight_converter.rb`)
- [x] `to_kg(value, from_unit)` - convert any unit to kg
- [x] `from_kg(value, to_unit)` - convert kg to any unit
- [x] `machine_to_kg()` / `kg_to_machine()` - handle machine display units and weight ratios
- [x] Handle machine display units vs user preference
- [x] Full test coverage (`test/services/weight_converter_test.rb`)

### 5.2 Display Helpers
- [x] `weight_display(kg_value, precision:)` helper - formatted with unit
- [x] `weight_value(kg_value)` helper - numeric value only
- [x] `weight_unit` helper - current user's unit preference
- [x] Input fields convert on submit via controller

---

## Phase 6: PWA & Offline Support

### 6.1 PWA Manifest
- [x] Update `manifest.json.erb`:
  - App name, icons (PNG + SVG)
  - Theme colors (dark)
  - Display: standalone
  - Start URL
  - App shortcuts (Start Workout, History, Exercises)

### 6.2 Service Worker
- [x] Cache app shell (HTML, CSS, JS)
- [x] Cache-first for static assets
- [x] Network-first for dynamic content
- [x] Skip Turbo Stream requests
- [x] Background sync event listener

### 6.3 Offline Workout Logging
- [x] IndexedDB for offline storage (haearn-offline)
- [x] `offline_controller.js` - network status detection
- [x] `offline_form_controller.js` - queue forms when offline
- [x] Offline indicator banner in layout
- [x] Auto-sync when back online
- [x] Service worker message passing for sync

### 6.4 Install Prompt
- [x] `install_prompt_controller.js` Stimulus controller
- [x] "Add to Home Screen" banner
- [x] Track installation with dismissal memory
- [x] Detect standalone mode

---

## Phase 7: Polish & UX

### 7.1 Dashboard
- [x] Current workout status (active workout indicator)
- [x] Recent workouts (last 5 completed)
- [x] Quick stats (workouts this week, volume, PRs)
- [x] Quick-start buttons (Start Workout, View History)
- [x] Workout frequency chart
- [x] Split dashboard into Overview + Analytics tabs (graphs moved to dedicated `dashboard#analytics` page)

### 7.2 Mobile Optimization
- [x] Touch-friendly tap targets (44px minimum)
- [x] `swipeable_controller.js` for swipe gestures
- [x] Bottom navigation bar (`_bottom_nav.html.erb`)
- [x] Safe area padding for notched devices
- [x] iOS font-size fix to prevent zoom
- [x] Settings button in navbar (replaces hamburger menu on mobile)
- [x] Analytics access in bottom navigation for mobile users

### 7.3 User Settings
- [x] Settings page (`SettingsController`)
- [x] Profile settings (name, email)
- [x] Password change with current password verification
- [x] Preferences:
  - [x] Preferred weight unit (kg/lbs)
  - [x] Default rest timer duration (30-300 seconds, slider)
- [x] Sign out
- [x] New workout blocks default to user's preferred rest duration
- [x] `rest_slider_controller.js` for live slider display

### 7.4 Turbo Enhancements
- [x] Turbo Frames for all CRUD (already implemented)
- [x] Turbo Streams for real-time set updates (already implemented)
- [x] `loading_controller.js` for loading states
- [x] Skeleton loading CSS classes
- [x] Custom turbo-progress-bar styling

---

## Phase 7.5: Granular Tracking (Future)

### 7.5.1 Equipment Modifiers
- [x] Belt used (boolean per set) - PRs with/without are different
- [x] Wraps/sleeves (knee, wrist, elbow)
- [x] Straps used (for grip-limited exercises)
- [x] Track "raw" vs "equipped" PRs separately _(PR calculator now supports equipped/raw filtering; history shows heaviest raw and equipped sets separately, and live set rows show `RAW PR`/`EQ PR` badges)_

### 7.5.2 Exercise Variations
- [x] Grip width (close/normal/wide)
- [x] Stance (narrow/normal/wide/sumo)
- [x] Incline/decline angle for benches
- [x] Bar type (straight, EZ-curl, SSB, trap bar, cambered)
- [x] Store as modifiers on WorkoutExercise, not separate exercises

### 7.5.3 Set Outcomes
- [x] Failed rep tracking (attempted but didn't complete)
- [x] Partial reps (half reps, cheat reps)
- [x] Spotter assisted (and how much help)
- [x] Pain/discomfort flag on set (something tweaked)

### 7.5.4 Advanced Loading
- [x] Band tension (accommodating resistance)
- [x] Chain weight
- [x] Blood flow restriction (BFR) sets
- [x] Tempo prescription (3-1-2-0 format: eccentric-pause-concentric-pause)

### 7.5.5 Form Video
- [ ] Record video of a set (Active Storage, local)
- [ ] Attach video to specific ExerciseSet
- [ ] Quick playback for form review
- [ ] Optional: side-by-side comparison of same lift over time

### 7.5.6 Exercise Cues
- [x] Personal form reminders per exercise ("squeeze at top", "elbows tucked")
- [x] Display cues when exercise is selected
- [x] Quick-add cues during workout

---

## Database Schema Diagram

```
┌─────────────────────┐
│        User         │
├─────────────────────┤
│ id                  │
│ email               │
│ password_digest     │
│ name                │
│ preferred_unit      │
│ default_rest_seconds│
└──────────┬──────────┘
         │
    ┌────┴────┬──────────────────┐
    │         │                  │
    ▼         ▼                  ▼
┌───────┐ ┌─────────┐    ┌──────────┐
│  Gym  │ │Exercise │    │ Workout  │
├───────┤ ├─────────┤    ├──────────┤
│ name  │ │ name    │    │ gym_id   │
│ notes │ │ type    │    │ notes    │
└───┬───┘ │has_weight│   │started_at│
    │     └─────────┘    └────┬─────┘
    │                         │
    ▼                         ▼
┌─────────┐           ┌──────────────┐
│ Machine │           │ WorkoutBlock │
├─────────┤           ├──────────────┤
│ name    │           │ position     │
│equip_type│          │ rest_seconds │
│weight_ratio│        └──────┬───────┘
│display_unit│               │
└─────────┘                  ▼
                     ┌─────────────────┐
                     │ WorkoutExercise │
                     ├─────────────────┤
                     │ exercise_id     │
                     │ machine_id      │
                     │ position        │
                     │ session_notes   │
                     │ persistent_notes│
                     └────────┬────────┘
                              │
                              ▼
                      ┌─────────────┐
                      │ ExerciseSet │
                      ├─────────────┤
                      │ is_warmup   │
                      │ weight_kg   │
                      │ reps        │
                      │ duration_sec│
                      │ distance_m  │
                      │ completed_at│
                      └─────────────┘
```

---

## API Endpoints (for future reference)

All endpoints return HTML with Turbo or Turbo Stream responses.

```
# Authentication
GET    /sign_in
POST   /sessions
DELETE /sessions
GET    /sign_up
POST   /users

# Gyms
GET    /gyms
POST   /gyms
GET    /gyms/:id
PATCH  /gyms/:id
DELETE /gyms/:id

# Machines (nested)
GET    /gyms/:gym_id/machines
POST   /gyms/:gym_id/machines
GET    /gyms/:gym_id/machines/:id
PATCH  /gyms/:gym_id/machines/:id
DELETE /gyms/:gym_id/machines/:id

# Exercises
GET    /exercises
POST   /exercises
GET    /exercises/:id
PATCH  /exercises/:id
DELETE /exercises/:id

# Workouts
GET    /workouts
POST   /workouts
GET    /workouts/:id
PATCH  /workouts/:id
DELETE /workouts/:id
POST   /workouts/:id/finish

# Workout Blocks
POST   /workouts/:workout_id/blocks
PATCH  /workouts/:workout_id/blocks/:id
DELETE /workouts/:workout_id/blocks/:id

# Workout Exercises
POST   /blocks/:block_id/exercises
PATCH  /workout_exercises/:id
DELETE /workout_exercises/:id

# Sets
POST   /workout_exercises/:workout_exercise_id/sets
PATCH  /sets/:id
DELETE /sets/:id
```

---

## Style Guide

### Colors
```scss
// Primary palette
$background-dark: #121212;
$background-card: #1a1a1a;
$background-elevated: #242424;

// Accent colors
$iron-primary: #71797E;      // Gunmetal gray
$iron-light: #A9A9A9;        // Dark gray
$rust-accent: #B7410E;       // Rust orange
$rust-light: #CD5C5C;        // Indian red

// Functional
$success: #28a745;
$warning: $rust-accent;
$danger: #dc3545;
$info: #17a2b8;

// Text
$text-primary: #e0e0e0;
$text-secondary: #9e9e9e;
$text-muted: #6c757d;
```

### Typography
- Headers: Bold, industrial feel
- Body: Clean, readable
- Numbers: Monospace for alignment

---

## Testing Strategy

### Unit Tests
- Model validations
- Weight conversion logic
- PR calculations

### Integration Tests
- Authentication flow
- Workout creation flow
- Set logging

### System Tests
- Full workout session
- Superset creation
- Timer functionality

---

## Milestones

| Milestone | Target | Description |
|-----------|--------|-------------|
| M1 | Week 1 | Auth + Dark theme + Basic models |
| M2 | Week 2 | Gyms, Machines, Exercises CRUD |
| M3 | Week 3-4 | Core workout logging |
| M4 | Week 5 | History & basic progress |
| M5 | Week 6 | Charts & PRs |
| M6 | Week 7-8 | PWA & Offline |
| M7 | Ongoing | Polish & refinement |

---

## Phase 8: Advanced Training Features

### 8.1 Workout Templates & Programs
- [x] Create reusable workout templates from past workouts
- [ ] Program builder (weekly schedules, mesocycles)
- [ ] Popular split templates (PPL, Upper/Lower, Full Body)
- [ ] Deload week automation (reduce volume/intensity by %)
- [ ] Program progression rules (linear, double progression, wave loading)

### 8.2 Auto-Regulation & Suggestions
- [x] RPE (Rate of Perceived Exertion) logging per set
- [x] RIR (Reps in Reserve) tracking
- [x] Auto-suggest weight increases based on performance _(ProgressionSuggester analyzes RPE/RIR trends, suggests when RPE < 8 or RIR > 2, dynamic increments 2.5-10kg, shown inline during workout and in exercise history)_
- [x] Fatigue indicator (compare current vs typical performance) _(FatigueAnalyzer compares volume/reps/RPE to 10-session baseline, shows 4 status levels on dashboard and during active workout)_
- [x] "Ready to progress" notifications when hitting rep targets consistently _(ProgressionReadinessChecker alerts when hitting reps for 3+ sessions, shown on dashboard with detailed analysis)_

### 8.3 1RM Calculator & Projections
- [x] Calculate estimated 1RM from any set (Epley, Brzycki formulas) _(OneRmCalculator service, shown on exercise history)_
- [x] Track e1RM trends over time _(e1RM trend chart on exercise history page)_
- [ ] Percentage-based programming (work at 80% of 1RM, etc.)
- [ ] Strength standards comparison (beginner → elite)

### 8.4 Advanced Set Types
- [x] Drop sets (weight decrements tracked) _(set_type field on ExerciseSet, badge display)_
- [x] Rest-pause sets (micro-rest within set) _(set_type: rest_pause)_
- [x] Cluster sets (inter-rep rest) _(set_type: cluster)_
- [x] Myo-reps / Back-off sets _(set_type: myo_rep, backoff)_
- [x] AMRAP sets (as many reps as possible, flag for PR tracking) _(is_amrap boolean, already existed)_
- [x] Tempo tracking (eccentric/pause/concentric, e.g., 3-1-2) _(4-field tempo: ecc/pause_bottom/con/pause_top, displayed as 3-1-2-0)_

### 8.5 Warm-up Generator
- [x] Auto-generate warmup sets for working weight
- [x] Configurable progression (e.g., bar → 50% → 70% → 85% → work sets)
- [x] One-tap "add warmups" to exercise

### 8.6 Body Metrics Tracking
- [x] Bodyweight log (morning weigh-ins) _(BodyMetric model with datetime, weight_kg, measurements in cm, trend charts)_
- [x] Body measurements (arms, chest, waist, legs) _(Optional measurements: chest, waist, hips, left/right arms, left/right legs in cm)_
- [x] Progress photos with date overlay _(ProgressPhoto model with Active Storage, category poses, date/weight overlay, comparison view)_
- [x] Wilks/DOTS/IPF GL score calculation for powerlifters _(WilksCalculator service with 2020 formula, shows score + classification: novice → world class)_
- [x] Bodyweight-relative strength tracking (e.g., 2x BW squat) _(Displays on exercise history PRs, shows ratio like "2.1x BW" with best lift @ bodyweight)_
- [x] Mobile/PWA quick access for body metrics via Settings quick links _(Added a `Body Metrics` link to mobile Settings quick links; logging remains accessible from the Body Metrics page.)_

### 8.7 Recovery & Readiness
- [ ] Sleep quality logging (hours, rating)
- [ ] Muscle soreness tracker (body map)
- [ ] Recovery score based on recent volume + rest
- [ ] Suggest rest days when volume is excessive

---

## Phase 9: Data & Analysis

### 9.1 Data Export/Import
- [ ] Export workouts to CSV/JSON (routes defined but not implemented)
- [ ] Export PR history
- [ ] Import from other apps (Strong, Hevy, etc.)
- [ ] Backup/restore functionality

### 9.2 Advanced Analytics
- [x] Volume per muscle group (7-day recovery map on dashboard)
- [ ] Training frequency heatmap
- [ ] Exercise balance analysis (push/pull ratio, anterior/posterior)
- [x] Plateau detection (no PR in X weeks)
- [x] Workout consistency streaks

### 9.3 Comparison Tools
- [ ] Compare any two workouts side-by-side
- [ ] Week-over-week volume comparison
- [ ] "This time last year" view

### 9.4 Weekly Email Summary
- [x] Add `weekly_summary_email` boolean to users (opt-in, default false)
- [x] Create `WeeklySummaryCalculator` service:
  - Calculates weekly stats (workouts, volume, sets, reps, duration)
  - Compares to 12-week historical average with percentages
  - Generates highlights (volume spikes, consistency, PR achievements)
  - Returns top 5 exercises by volume
  - Detects new PRs from the week
  - Tracks consistency and training streaks (max 52 weeks)
- [x] Create `WeeklySummaryMailer` with dark theme templates:
  - HTML email matching website aesthetic (iron/rust colors)
  - Plain text fallback
  - Comprehensive weekly insights and comparisons
- [x] Create `SendWeeklySummariesJob` for batch email sends
- [x] Configure recurring job (every Sunday at 6am via `recurring.yml`)
- [x] Add settings UI toggle for email preference
- [x] Add mailer preview for testing (`/rails/mailers`)

---

## Phase 10: Quality of Life

### 10.1 Exercise Management
- [ ] Exercise substitution suggestions (similar movement patterns)
- [ ] Mark machines as broken/unavailable at gym
- [ ] Equipment "favorites" for quick selection
- [ ] Exercise notes/cues library (form reminders)

### 10.2 Injury Management
- [ ] Log injuries with affected body parts
- [ ] Auto-flag exercises that stress injured areas
- [ ] "Safe alternatives" suggestions during injury

### 10.3 Competition Mode (Powerlifting)
- [ ] Meet day tracker (3 attempts per lift)
- [ ] Attempt selection helper
- [ ] Meet history and totals
- [ ] Weigh-in countdown

---

## Phase 11: Workflow & Convenience

### 11.1 Quick-Swap Exercise Mid-Workout
- [x] "Swap" action on WorkoutExercise opens exercise/machine picker
- [x] Replaces exercise_id/machine_id in-place, preserving block position and logged sets
- [x] Common scenario: equipment is occupied, swap to an alternative fast

### 11.2 Auto-Fill Weight From Last Session
- [x] Pre-fill weight (and reps) inputs from the corresponding set of the previous session
- [x] "Copy last" button on set form for one-tap population
- [x] Progression suggester can override with its recommended weight

### 11.3 Workout Pinning / Favorites on Dashboard
- [x] Pin/favorite workouts or templates for quick access
- [x] Dashboard shows pinned workouts with one-tap "Start this again"
- [x] Faster than scrolling history to find and copy a routine

### 11.4 Calendar View for Workout History
- [x] Monthly calendar grid with colored dots on training days
- [x] Clickable days to filter/view that day's workout(s)
- [x] Complements existing streak and frequency charts for spotting consistency gaps
- [x] Mobile calendar simplified to activity-colored cells + workout-count indicator (hide per-day volume/set details on small screens)
- [x] Added stronger activity heat tiers (1/2/3/4+ workouts) with higher-contrast count badges for faster mobile scanning

### 11.5 Per-Block Rest Timer Configuration
- [x] Expose rest time adjuster on each block header during active workout
- [x] Compound lifts need 3-5 min, accessories need 60-90s
- [x] Block already has `rest_seconds` in schema — surface it in the UI

### 11.6 Prioritized Existing Items
- [x] **Data export (CSV/JSON)** — Fully implemented in SettingsController (export_data, export_csv, export_prs).
- [x] **AMRAP sets** — Boolean flag on ExerciseSet + badge. Many popular programs (5/3/1, nSuns, GZCLP) rely on AMRAP final sets.
- [x] **Percentage-based programming** — With e1RM tracking already built, let users input "5x5 @ 80%" and auto-calculate working weight.

---

## Phase 11.7 Regression Safety Net

- [x] Add RSpec regression suite for high-risk UI flows (workout show actions, timer markup transitions, machine-unit set display, settings quick links)
- [x] Configure RSpec to use existing Rails fixtures (`test/fixtures`) for fast, deterministic request/helper specs
- [x] Expand RSpec safety net to cover core gym-user workflows (auth guardrails, workout lifecycle start/add/log/finish, settings preference updates)
- [x] Add RSpec coverage for push notification persistence endpoints (subscription create/remove, rest-timer notification dedupe)
- [x] Add RSpec coverage for admin audit log access/filter behavior (admin-only access + action filtering)

---

## Phase 12: Admin Panel & Authorization (Pundit)

### 12.1 Pundit Setup & Admin Role
- [x] Add `pundit` gem to Gemfile
- [x] Run `bundle install`
- [x] Add `admin` boolean column to `users` table (default: `false`)
- [x] Run `rails generate pundit:install` to create `ApplicationPolicy`
- [x] Include `Pundit::Authorization` in `ApplicationController`
- [x] Add `after_action :verify_authorized` (with appropriate skips)
- [x] Create admin seed user in `db/seeds.rb`

### 12.2 Authorization Policies
- [x] `UserPolicy` — admin can list/edit/destroy any user; users can edit own profile
- [x] `ExercisePolicy` — admin can CRUD global exercises (user_id: nil); users can only CRUD their own
- [x] `GymPolicy` — users manage own gyms; admin can view all
- [x] `MachinePolicy` — users manage own machines; admin can view all
- [x] `WorkoutPolicy` — users manage own workouts; admin can view all
- [x] `WorkoutTemplatePolicy` — admin can create "official" templates; users manage own
- [x] `BodyMetricPolicy` — users manage own; admin can view all (aggregate stats)

### 12.3 Admin Namespace & Layout
- [x] Create `Admin::` namespace with `admin/` route prefix
- [x] Admin-specific layout with distinct styling (iron-red accent header/sidebar)
- [x] Admin dashboard (`Admin::DashboardController`) with:
  - Total users / active users (last 7/30 days)
  - Total workouts logged (this week/month/all time)
  - New registrations chart
  - Most popular exercises
  - System health (DB size, storage usage)
- [x] Navigation: Dashboard, Users, Exercises, Analytics

### 12.4 User Management
- [x] `Admin::UsersController` — list, show, edit, deactivate users
- [x] Search/filter users by name, email, signup date, activity
- [x] View user stats (workouts, volume, last active)
- [x] Grant/revoke admin role
- [x] Deactivate/reactivate accounts (soft delete, not hard delete)
- [x] Impersonate user for debugging (with audit log)

### 12.5 Global Exercise Management
- [x] `Admin::ExercisesController` — full CRUD for global exercises (user_id: nil)
- [ ] Bulk import/edit exercises
- [x] Manage exercise categories and muscle group mappings
- [x] Review user-created exercises for promotion to global library
- [x] Merge duplicate exercises

### 12.6 Content & Data Administration
- [x] View aggregate analytics (most used exercises, popular gyms, avg workout duration)
- [ ] Manage workout templates flagged as "official"
- [ ] Data export tools (all users, all workouts — CSV/JSON)
- [x] Audit log for admin actions (who did what, when)

### 12.7 Admin Access Control
- [x] `before_action` guard in `Admin::BaseController` requiring admin role
- [x] Redirect non-admins with flash message
- [ ] Rate-limit admin actions (optional)
- [x] Admin activity log (track logins, user edits, exercise changes)

---

## Phase 13: Data Model Alignment

### 13.1 Machine Optionality Consistency
- [ ] Align `workout_exercises.machine_id` nullability with product intent (optional machine support)
- [ ] Update model validations/associations and controller flows for true optional machine selection
- [ ] Add migration + backfill strategy for existing records
- [ ] Add regression tests for workout logging, history, PRs, and filters when machine is nil

---

## Phase 14: Offline Sync Reliability

### 14.1 Conflict Detection & Resolution
- [ ] Define conflict policy for offline queued actions (last-write-wins vs timestamp/version checks)
- [ ] Detect stale updates/deletes during sync replay
- [ ] Surface conflict UI with user choices (keep local, keep server, merge where possible)
- [ ] Add idempotency keys/replay safeguards for queued set submissions
- [ ] Add end-to-end tests for offline create/edit/delete conflict scenarios

---

## Phase 15: Performance & Scalability

### 15.1 Analytics Query Hardening
- [ ] Add profiling pass for dashboard/history queries on large datasets
- [x] Add/adjust DB indexes for heavy filters/grouping paths (dates, user_id, exercise_id, machine_id) _(Added composite index `workouts(user_id, finished_at)` to accelerate per-user time range analytics queries.)_
- [x] Reduce N+1 and high-memory loops in analytics aggregations _(Removed exercise/machine lookup N+1 in dashboard readiness alerts and `PerformanceNotificationService#readiness_candidates`; consolidated weekly workout/tonnage/consistency loops into grouped weekly SQL buckets.)_
- [x] Introduce caching strategy for expensive aggregates/charts _(Added user-scoped short-TTL caching (`Rails.cache`) for expensive dashboard analytics datasets while keeping active-workout/readiness paths uncached. Added invalidation hooks on workout/workout_exercise/exercise_set commits, scoped key invalidation (only affected analytics keys), and per-request invalidation dedupe to avoid repeated cache deletes during multi-record updates.)_
- [x] Add performance regression checks (baseline timings for key pages) _(Added `performance:benchmark_dashboard` rake task with warmup/measured runs and avg/min/max timings for dashboard and notification hot paths.)_

---

## Phase 16: Notification System

### 16.1 In-App + Push Notifications
- [x] Build notification preferences (readiness alerts, streak risk, reminders, PR events) _(User-level toggles added in Settings for readiness/plateau/streak/volume-drop and rest timer in-app/push notifications; services/controllers now honor these preferences)_
- [x] Implement in-app notification center (recent alerts, read/unread state) _(Dynamic bell dropdown + dashboard panel powered by `notifications_center_controller`, polling JSON feed with mark-read/mark-all-read actions; rest timer expiry now enters the same in-app feed for consistency)_
- [x] Add Web Push subscription + delivery pipeline for PWA users _(Added `PushSubscription` persistence, subscription/unsubscribe endpoints, VAPID-backed `WebPushNotificationService`, and Settings-driven browser subscription flow via `notification_permission_controller`.)_
  - [x] Added `bin/rails web_push:generate_keys` task for OpenSSL 3-compatible VAPID key generation.
- [x] Trigger notifications from progression/readiness/streak events _(PerformanceNotificationService generates plateau/readiness/streak risk/volume drop alerts and stores deduped notifications per user)_
- [x] Calibrate notification sensitivity (week-to-date volume drop guardrails; machine-scoped fatigue baseline comparisons)
- [ ] Add delivery audit + retry logic for failed notification sends

---

## Phase 17: Program Execution Workflow

### 17.1 Daily Prescription UX
- [ ] Build "Today’s Session" view from active program/template
- [ ] Show prescribed sets/reps/percentages with quick logging actions
- [ ] Track completion status per prescribed set/exercise/session
- [ ] Add adherence scoring (planned vs completed volume/sets)
- [ ] Add skip/modify flows with reason tracking (equipment busy, fatigue, pain, time)

---

## Phase 18: Backup & Recovery Operations

### 18.1 Operational Data Safety
- [ ] Define scheduled backup policy for DB + Active Storage files
- [ ] Implement backup integrity verification (checksum/restore validation)
- [ ] Add documented restore drill process with recovery time targets
- [ ] Add attachment consistency checks (orphan blobs/records)
- [ ] Add admin-facing backup/restore status dashboard

---

## Phase 19: Database Access Optimization

### 19.1 Query Shape Improvements
- [x] Replace query-per-week dashboard loops with grouped weekly aggregation helpers
- [x] Remove `Exercise` / `Machine` lookup N+1 patterns in readiness pipelines
- [x] Remove unnecessary readiness joins _(Switched readiness combo queries to join only `workout_exercises` and pluck `exercise_id/machine_id` directly.)_
- [x] Batch historical PR/plateau calculations to avoid per-exercise history queries _(Refactored dashboard PR timeline + plateau detector and notification plateau candidates to prefetch/group sets once, eliminating per-exercise history queries.)_
- [x] Review and optimize template-building aggregate queries _(Refactored `WorkoutTemplatesController#create_from_workout` to preload nested associations and compute set targets in memory, removing per-exercise `average/count` queries.)_
- [x] Consolidate week-over-week comparison queries _(Reduced repeated count/sum queries by grouping workouts, sets, and volume once across both weeks and reusing bucketed results.)_
- [x] Batch muscle analytics aggregation _(Replaced per-exercise `exercise_sets.where(...)` loops with single-pass set plucks for 7-day recovery and 30-day balance analytics.)_
- [x] Optimize training density calculation _(Precomputed per-workout volume via grouped query and preloaded gyms, removing per-workout volume query pattern.)_
- [x] Optimize admin registration chart aggregation _(Replaced one query per week with grouped weekly user-registration counts.)_
- [x] Optimize exercise frequency aggregation _(Grouped by `exercise_id` first and resolved names in one lookup instead of grouping directly on joined exercise names.)_
- [x] Optimize notification refresh query shape _(Replaced dual week-volume queries with one grouped lookup and preloaded existing notifications by `dedupe_key` to avoid per-candidate find-or-initialize queries.)_

### 19.2 Indexing & Verification
- [x] Add composite index for user scoped workout date queries (`workouts(user_id, finished_at)`)
- [x] Add supporting admin-metrics indexes (`users.created_at`, `users.updated_at`, `workouts.created_at`) to speed registration/activity/workout trend counters
- [x] Run `EXPLAIN QUERY PLAN` on dashboard and notification hot paths _(Verified weekly counts/volume and readiness/plateau paths use indexed lookups, especially `index_workouts_on_user_id_and_finished_at`; remaining temp B-tree usage is expected for grouped/distinct aggregations.)_
- [x] Add performance notes + benchmark snapshots to docs _(Captured query plans and added repeatable timing baseline task: `bin/rails performance:benchmark_dashboard RUNS=10 WARMUP=2`.)_

### 19.3 Further Optimizations (Next)
- [x] Add instrumentation for dashboard analytics cache hit/miss rates and invalidation counts (user-scoped metrics) _(Dashboard analytics now fetch through `DashboardAnalyticsCache.fetch` with per-user daily counters for `cache_hit`, `cache_miss`, and `invalidation`, plus `ActiveSupport::Notifications` instrumentation for fetch/invalidation events.)_
- [x] Add chart-level cache key versioning so invalidation can target smaller subsets without clearing full analytics bundles _(Dashboard analytics cache keys now include per-user per-chart version tokens; invalidation bumps only affected chart versions instead of broad cache-key deletes.)_
- [ ] Add optional async pre-warm job for expensive analytics datasets after workout completion _(Deferred to later)_
- [ ] Add seeded large-data benchmark profile and track timing trends in CI artifacts _(Deferred to later)_
- [ ] Evaluate pre-aggregated daily/weekly rollups for very large histories (opt-in path once dataset thresholds are exceeded) _(Deferred to later)_

---

## Phase 20: Push Reliability & Operations

### 20.1 Delivery Reliability
- [x] Add push delivery observability (attempt/success/failure counters by error class and endpoint host) _(Added `WebPushNotificationService` metrics counters with host/error-class bucketing and query/reset helpers, covered by service tests.)_
- [x] Add retry pipeline with backoff for transient push delivery failures _(Added transient-only retries in `WebPushNotificationService` with exponential backoff for timeout/network and 429/5xx push service responses; permanent subscription errors still fail fast and prune invalid subscriptions.)_
- [x] Add subscription health indicators (subscribed device count + last successful push timestamp) _(Added `last_successful_push_at` tracking on `PushSubscription`, surfaced via `WebPushNotificationService.subscription_health_for`, and displayed in Settings push section.)_

### 20.2 Runtime Safety
- [ ] Add service worker versioning + cache invalidation rollout checklist
- [ ] Add environment parity smoke check for push (config present, subscribe/unsubscribe, test delivery)
- [ ] Add structured Web Push error logging (user_id, subscription_id, endpoint host, sanitized backtrace)

---

## Phase 21: Gym User Experience

### 21.1 In-Gym Flow Optimization
- [x] **NEXT: Default new equipment unit to the user's preferred unit** _(Implemented defaulting in machine creation flows: new forms preselect `Current.user.preferred_unit`, create action persists that default when `display_unit` is blank, and regression tests cover both default and explicit override.)_
- [x] **Unit consistency audit fix** _(Machine-linked set-entry UI now uses machine input unit for labels/placeholder/calculator params and converts stored kg values back to machine display units in add/edit forms; non-machine entries continue to use user preferred unit.)_
- [ ] Add backup exercise autosuggest with available-equipment filtering when stations are occupied
- [x] Add offline confidence mode showing queued action count and sync status at a glance _(Added global offline confidence widget with online/offline/syncing/error state, queued action count, last synced timestamp, and manual retry action wired to `offline_controller` queue sync.)_
- [x] Add locker-room quick log flow (voice/one-thumb fast entry between stations) _(Added Quick Log mode toggle on active workouts and simplified one-thumb set form layout with larger inputs and single-tap “Log Set” submission.)_
- [x] Add personal equipment setup memory surfaced by gym + machine (seat/pin/handle defaults) _(Added `seat_setting`/`pin_setting`/`handle_setting` on machines, with summary display on machine cards and active workout exercise cards.)_
- [x] Add plate-load sanity checks for impossible combinations by selected bar/machine _(Plate calculator now surfaces warnings for below-bar targets, uneven side loading, impractical plate count per side, and non-exact plate combinations.)_

---

## Notes for Future Development

- Barcode scanning for gym machines?
- Integration with fitness trackers / Apple Health?
- Heart rate zone tracking for conditioning work?
- Video form check with rep counter (ML)?
- Push notification foundation is now in place (subscription storage + VAPID delivery). Remaining work is delivery auditing/retry policy and expanding trigger coverage.
