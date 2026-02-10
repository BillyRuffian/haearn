# Haearn Implementation Plan

> Last Updated: February 3, 2026

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

### 7.2 Mobile Optimization
- [x] Touch-friendly tap targets (44px minimum)
- [x] `swipeable_controller.js` for swipe gestures
- [x] Bottom navigation bar (`_bottom_nav.html.erb`)
- [x] Safe area padding for notched devices
- [x] iOS font-size fix to prevent zoom
- [x] Settings button in navbar (replaces hamburger menu on mobile)

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
- [ ] Belt used (boolean per set) - PRs with/without are different
- [ ] Wraps/sleeves (knee, wrist, elbow)
- [ ] Straps used (for grip-limited exercises)
- [ ] Track "raw" vs "equipped" PRs separately

### 7.5.2 Exercise Variations
- [ ] Grip width (close/normal/wide)
- [ ] Stance (narrow/normal/wide/sumo)
- [ ] Incline/decline angle for benches
- [ ] Bar type (straight, EZ-curl, SSB, trap bar, cambered)
- [ ] Store as modifiers on WorkoutExercise, not separate exercises

### 7.5.3 Set Outcomes
- [ ] Failed rep tracking (attempted but didn't complete)
- [ ] Partial reps (half reps, cheat reps)
- [ ] Spotter assisted (and how much help)
- [ ] Pain/discomfort flag on set (something tweaked)

### 7.5.4 Advanced Loading
- [ ] Band tension (accommodating resistance)
- [ ] Chain weight
- [ ] Blood flow restriction (BFR) sets
- [ ] Tempo prescription (3-1-2-0 format: eccentric-pause-concentric-pause)

### 7.5.5 Form Video
- [ ] Record video of a set (Active Storage, local)
- [ ] Attach video to specific ExerciseSet
- [ ] Quick playback for form review
- [ ] Optional: side-by-side comparison of same lift over time

### 7.5.6 Exercise Cues
- [ ] Personal form reminders per exercise ("squeeze at top", "elbows tucked")
- [ ] Display cues when exercise is selected
- [ ] Quick-add cues during workout

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
- [ ] Fatigue indicator (compare current vs typical performance)
- [ ] "Ready to progress" notifications when hitting rep targets consistently

### 8.3 1RM Calculator & Projections
- [x] Calculate estimated 1RM from any set (Epley, Brzycki formulas) _(OneRmCalculator service, shown on exercise history)_
- [x] Track e1RM trends over time _(e1RM trend chart on exercise history page)_
- [ ] Percentage-based programming (work at 80% of 1RM, etc.)
- [ ] Strength standards comparison (beginner → elite)

### 8.4 Advanced Set Types
- [ ] Drop sets (weight decrements tracked)
- [ ] Rest-pause sets (micro-rest within set)
- [ ] Cluster sets (inter-rep rest)
- [ ] Myo-reps / Back-off sets
- [ ] AMRAP sets (as many reps as possible, flag for PR tracking)
- [ ] Tempo tracking (eccentric/pause/concentric, e.g., 3-1-2)

### 8.5 Warm-up Generator
- [x] Auto-generate warmup sets for working weight
- [x] Configurable progression (e.g., bar → 50% → 70% → 85% → work sets)
- [x] One-tap "add warmups" to exercise

### 8.6 Body Metrics Tracking
- [ ] Bodyweight log (morning weigh-ins)
- [ ] Body measurements (arms, chest, waist, legs)
- [ ] Progress photos with date overlay
- [ ] Wilks/DOTS/IPF GL score calculation for powerlifters
- [ ] Bodyweight-relative strength tracking (e.g., 2x BW squat)

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

## Notes for Future Development

- Barcode scanning for gym machines?
- Integration with fitness trackers / Apple Health?
- Heart rate zone tracking for conditioning work?
- Video form check with rep counter (ML)?
- **Push notifications for PRs** - Would require server-side infrastructure (web push subscription management, background sync). Local notifications for rest timer already implemented.
