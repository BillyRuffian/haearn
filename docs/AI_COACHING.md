# AI workout coaching

Completed workouts receive asynchronous coaching through the official `openai` Ruby SDK and Responses API. Haearn stores the workouts, computes the metrics, and retains versioned analyses locally. OpenAI receives a compact context for interpretation; it is never used to retrieve training history.

## Configuration

Set `OPENAI_API_KEY` in the Rails **web and job worker** environment, or add an `openai.api_key` entry using `bin/rails credentials:edit`. Never put an API key in source control. The existing Kamal deployment passes `RAILS_MASTER_KEY`, so encrypted Rails credentials work without adding another deployment secret. For environment-based deployment, add `OPENAI_API_KEY` to the deployment's `env.secret` list and supply it through `.kamal/secrets` using your existing secret source. Never put the key in `env.clear`.

| Setting | Default | Purpose |
| --- | --- | --- |
| `OPENAI_WORKOUT_MODEL` | `gpt-5-mini` | Structured-output-compatible model |
| `OPENAI_WORKOUT_TIMEOUT` | `90` | API deadline in seconds, clamped to 5–300 |
| `OPENAI_WORKOUT_HISTORY_SESSIONS` | `6` | Prior sessions per exact exercise/machine, clamped to 1–8 |
| `OPENAI_WORKOUT_MAX_OUTPUT_TOKENS` | `6000` | Output budget including reasoning, clamped to 1,000–16,000 |
| `OPENAI_WORKOUT_PROMPT_VERSION` | `workout-v1` | Version defined in `Ai::Prompts`; retain old versions for queued jobs |

All defaults live in `Ai::Config`. The model and prompt version are captured on each analysis record. An unknown prompt version fails the attempt safely. The request uses strict JSON-schema output, no tools, no conversation history, and `store: false`. API retention remains subject to the OpenAI account's policies. The API receives exercise/equipment names, limited workout/setup notes, set values, and local metrics; it receives no account email, user profile, photos, or full database export. The compact input snapshot is stored locally for reproducibility. Treat it as private workout data.

Without a key, attempts fail with `not_configured`; completing and editing workouts still works. Configure the key and use **Retry coaching** afterward. No real API requests are made by the automated tests.

Run `bin/rails db:migrate` after installing dependencies. Production uses the existing Solid Queue worker managed by Puma (`SOLID_QUEUE_IN_PUMA=true`). Development uses Rails' default in-process async adapter; keep `bin/dev` running until the job finishes. If the process stops mid-analysis, the UI permits recovery after ten minutes. Use a persistent job adapter if development jobs need to survive restarts.

## Flow and files

1. A committed transition from active to completed calls `Ai::RequestWorkoutAnalysis`. Repeated Finish/offline replay requests preserve the original completion timestamp and analysis.
2. The service creates a `WorkoutAnalysis` and queues `AnalyseWorkoutJob`. Queue failure cannot roll back a completed workout; it records `enqueue_failed` when the analysis row is available.
3. The job claims the row atomically. `Ai::WorkoutContextBuilder` loads the workout and up to six earlier setful sessions for each exact `(exercise_id, machine_id)` pair. Equipment-free (`nil`) is its own scope. Repeated occurrences in one workout form a single historical session. History sorts by visible workout date, excludes later dates and other users, and preserves set completion/position order.
4. `TrainingProgressionCalculator` computes working-set load volume, previous-session comparisons, best eligible e1RM, rep/load trends, consecutive load sessions, and snapshot-based target attainment. `TrainingWeeklyMetrics` supplies four UTC calendar weeks of primary-muscle frequency, volume, working sets, and known hard sets. The current week is labelled partial; it must not be directly treated as a full-week regression. Exact-exercise frequency covers the preceding 28 days, including the current session.
5. `Ai::WorkoutAnalyser` sends the frozen context through `Ai::Client`, validates JSON schema and exercise identities, and returns structured results. The job persists validated coaching plus summary, response ID, timestamps, and token usage.
6. The completed-workout **AI Coaching** panel polls while pending/processing, stops when terminal, and includes manual refresh, retry, reanalysis, and links to the ten latest analysis versions. Older records remain available through the scoped version endpoint and Rails console.

Warmups and sets without completion timestamps are omitted from working-set metrics. Load volume is recorded external load × reps (`kg·reps`), excluding band/chain additions; it is not physiological workload. e1RM uses the existing Epley calculator only for ordinary, unassisted, full-range 1–10 rep weighted sets. Unknown metrics remain null. A possible plateau requires at least four comparable sessions; one weak workout is not a regression trend. Hard sets are counted only where recorded RPE ≥ 7 or RIR ≤ 3; unrecorded effort is unknown. Set totals and load volume are distinct from this effort-based count.

Programmed targets use `ProgramSessionExecution.prescription`, never later edits to a template. Workouts launched directly from mutable templates have no immutable target snapshot, so target attainment is unknown. Hypertrophy is the default goal because there is no structured goal field in the current user/program models. Raw and equipped flags and machine ratios are included for interpretation. Numeric recommended weights remain kg; the panel converts them to the recorded machine display unit/ratio or the user's preferred unit.

The input is capped at 120 KB, notes at 400 characters, and historical sessions at eight. Oversized inputs fail safely rather than silently claiming analysis of omitted exercises. No automatic full-history backfill occurs.

## Manual use, retries, and operations

From a development Rails console:

```ruby
workout = Workout.completed.find(123)
analysis = Ai::WorkoutAnalyser.call(workout) # enqueues and returns the record
analysis.reload.status
analysis.reload.error_message
analysis.reload.token_usage
```

**Retry coaching** and **Reanalyse workout** use that same pipeline. A manual request creates a new version after a completed/failed attempt, preserving the old input/results. Repeated clicks while an attempt is active reuse it. One active analysis per workout and automatic completion request keys have database uniqueness constraints. A stale attempt can be superseded after ten minutes, and old workers cannot overwrite the new attempt. If the workout is continued before/during processing, the old attempt fails safely; finishing again requests fresh coaching.

Network errors, timeouts, rate limits, HTTP 408/409, and server errors retry at most three times using Active Job's increasing delays. Retries reuse the same row and input snapshot. SDK retries are disabled to avoid multiplying requests. An interrupted network request may still have consumed API tokens; exactly-once remote execution cannot be guaranteed. Authentication, malformed JSON, refusal, incomplete output, invalid schema, or mismatched exercises fail without automatic retry. Retry manually after addressing the cause. Missing/deleted workouts are ignored safely.

Diagnostics store controlled error codes/classes and log analysis IDs/error classes, never API exception messages or response bodies. Token usage includes input/output totals and cached/reasoning counts when returned. It is usage telemetry, not a computed bill.

## Tests

```sh
bundle exec rspec spec/services/training_progression_calculator_spec.rb spec/services/ai_workout_context_builder_spec.rb spec/services/ai_workout_analysis_schema_spec.rb spec/helpers/workout_analyses_helper_spec.rb spec/jobs/analyse_workout_job_spec.rb spec/requests/workout_coaching_spec.rb
RUN_JS_SYSTEM_SPECS=1 bundle exec rspec spec/system/workout_coaching_spec.rb
bundle exec rubocop
```

Tests stub the OpenAI SDK boundary and exercise real context calculation, schema validation, job retries, persistence, and rendering. Browser coverage is guarded for environments without Chromium/socket support.

## Future weekly review

Reuse `TrainingProgressionCalculator`, `TrainingWeeklyMetrics`, `Ai::Client#structured_response`, and versioned `Ai::Prompts`. Add a weekly context/schema and its own persisted review/job when that feature is requested. A live-model coaching evaluation set, explicit per-user goals, and cost reporting are useful follow-ups; this implementation does not alter training prescriptions automatically.

API references: [Official Ruby SDK](https://developers.openai.com/api/reference/ruby), [Structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [GPT-5 mini capabilities](https://developers.openai.com/api/docs/models/gpt-5-mini).
