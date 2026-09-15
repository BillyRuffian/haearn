# Codex Instruction — Haearn AI Workout Coach

Implement an AI workout-coaching feature in Haearn.

Haearn is a Ruby/Rails application used to record resistance-training workouts. I want completed workouts to be analysed automatically by OpenAI and useful coaching feedback stored and displayed in Haearn.

The key architectural principle is:

**Haearn remains the source of truth for workout data. OpenAI interprets data supplied by Haearn; it must not become the workout database.**

## Goal

When a workout is marked complete:

1. Gather the completed workout and relevant historical training data.
2. Calculate useful progression metrics locally in Rails.
3. Send a compact structured representation to the OpenAI API.
4. Request structured coaching feedback.
5. Validate and store the response against the completed workout.
6. Display the analysis in the Haearn UI.
7. Do this asynchronously so completing a workout never waits for OpenAI.

Also lay the groundwork for a future weekly training review using the same architecture.

## First: inspect the existing application

Before changing code:

- inspect the existing Rails application structure;
- identify the Rails and Ruby versions;
- identify the database;
- understand the current models representing workouts, exercises, sets, sessions and users;
- inspect the existing test framework and conventions;
- inspect background-job infrastructure;
- inspect existing service-object/module conventions;
- inspect how credentials/environment variables are handled;
- inspect the existing workout completion flow.

Do not invent parallel abstractions where the application already has suitable ones.

Follow the existing project's naming, formatting and testing conventions.

## OpenAI integration

Use the current official OpenAI Ruby SDK and the current recommended **Responses API**.

Do not use deprecated Chat Completions APIs unless there is a compelling compatibility reason.

The OpenAI API key must come from application credentials or environment configuration. Never commit secrets.

Create a small OpenAI integration boundary rather than scattering API calls throughout the application.

A likely shape is something similar to:

    app/services/ai/
      client.rb
      workout_context_builder.rb
      workout_analyser.rb
      workout_analysis_schema.rb

Adapt this structure if Haearn already has a preferred architecture.

Controllers and models should not contain prompt construction or direct OpenAI API calls.

## Database model

Create a persisted representation of an AI analysis associated with a workout.

For example:

    WorkoutAnalysis
      workout_id
      status
      model
      prompt_version
      summary
      response_data (json/jsonb)
      input_data (json/jsonb, optional)
      error_message
      analysed_at
      created_at
      updated_at

Use appropriate Rails enums/statuses such as:

    pending
    processing
    completed
    failed

Avoid storing unnecessary sensitive information.

The raw structured input may be useful for debugging/reproducibility, but keep it compact.

The design should allow a workout to be reanalysed later and should not destroy previous analysis history unless the existing app conventions make a one-analysis-per-workout design clearly preferable.

## Trigger

When a workout transitions to completed, enqueue a background job.

For example:

    AnalyseWorkoutJob.perform_later(workout.id)

Use the job system already configured in Haearn.

Do not make workout completion dependent on OpenAI being reachable.

The job must be idempotent enough that retries do not generate uncontrolled duplicate analysis records.

Use normal Rails retry/error handling appropriate to the application's job backend.

## Workout context

Do not simply dump the database or every previous workout into the model.

Build a deterministic context object.

Include the completed workout:

- date
- workout/session type if available
- exercise names
- exercise IDs where useful
- equipment/machine variation where relevant
- each working set:
  - weight
  - repetitions
  - RPE/RIR if Haearn stores it
- warm-up sets may be omitted or clearly identified
- workout duration if available
- notes if relevant

Include useful training history for each exercise.

A reasonable default is approximately the previous 4–8 sessions containing that exercise.

Prefer selecting history relevant to the current workout rather than arbitrary recent workouts.

## Calculate progression metrics in Rails

Haearn should calculate objective numbers wherever possible instead of asking the language model to infer them.

For each exercise, calculate available metrics such as:

- previous-session load and reps
- total working-set volume
- previous-session volume
- volume percentage change
- best set
- estimated 1RM where meaningful
- estimated 1RM change
- number of consecutive sessions at the current load
- whether the programmed rep target has been reached
- recent progression trend
- recent performance regression
- number of working sets
- recent exercise frequency

If the application has sufficient data, also include weekly metrics such as:

- hard sets per muscle group
- training frequency per muscle group
- recent weekly volume trends

Keep metric-calculation logic separate from the AI integration so it is independently testable.

Do not fabricate metrics where the underlying data does not support them.

## Initial coaching philosophy

The analysis should assume resistance-training hypertrophy as the primary goal unless Haearn already stores goals per user/programme.

The AI should favour:

- progressive overload;
- consistency;
- keeping successful exercises;
- increasing load only when performance justifies it;
- small realistic progression;
- avoiding pointless programme churn.

The model should not recommend swapping exercises merely for variety.

It should distinguish normal session-to-session variation from a meaningful plateau.

It should not interpret one weak session as evidence that an exercise has stalled.

Where insufficient historical data exists, explicitly say so rather than pretending there is a trend.

## Prompt

Create a versioned system/developer prompt in application code.

The essence should be:

"You are a resistance-training coach analysing structured workout data supplied by Haearn.

Haearn has already calculated objective metrics. Treat those metrics as authoritative.

Your job is to interpret the workout in the context of recent training history.

Identify meaningful progression, regressions, emerging plateaus, fatigue patterns and sensible next-session targets.

Prefer progressive overload and consistency over unnecessary exercise changes.

Do not change an exercise simply for variety.

Do not infer facts that are absent from the supplied data.

If there is insufficient evidence for a conclusion, say so.

Recommend realistic next-session targets based on the trainee's recent performance.

Return only data conforming to the supplied structured response schema."

Keep user-specific preferences/data outside the hard-coded prompt where practical so the eventual feature can support multiple users.

## Structured response

Do not request free-form prose and then parse it manually.

Use OpenAI structured outputs / JSON schema support.

Design an explicit schema.

A good starting structure is:

    {
      "overall": {
        "rating": "excellent|good|mixed|poor",
        "summary": "...",
        "confidence": "high|medium|low"
      },

      "exercise_feedback": [
        {
          "exercise_id": "...",
          "exercise_name": "...",
          "status": "progressing|stable|possible_plateau|regressing|insufficient_data",
          "summary": "...",
          "observations": [
            "..."
          ],
          "next_session": {
            "weight": 37.5,
            "sets": 4,
            "target_reps": [10, 10, 10, 10],
            "instruction": "Keep the same weight and aim to complete four sets of ten."
          }
        }
      ],

      "workout_observations": [
        "..."
      ],

      "programme_recommendations": [
        "..."
      ]
    }

Use IDs to correlate feedback with Haearn exercises whenever possible rather than relying solely on exercise names.

Weights must remain numeric.

Allow next-session fields to be nullable when no recommendation can reasonably be made.

Validate the returned structure before persistence.

## Example behaviour

If previous incline dumbbell performance was:

    37.5 kg:
    10, 10, 8, 9

and today's workout was:

    37.5 kg:
    10, 10, 10, 9

a useful analysis would recognise genuine progression and recommend keeping 37.5 kg until the target, for example 4x10, is achieved rather than prematurely increasing the weight.

If several sessions have shown no progress, the analysis may identify a possible plateau, but it should avoid declaring a plateau from a single session.

## API configuration

Make the model configurable.

For example:

    OPENAI_WORKOUT_MODEL

Provide a sensible default compatible with structured outputs.

Do not hard-code model assumptions throughout the codebase.

Also make important AI configuration easy to change later, including:

- model
- timeout
- prompt version
- historical session count

Use one central configuration location.

## Failure handling

OpenAI failure must never break workout logging.

Handle:

- timeout
- API/network failure
- rate limiting
- malformed/unexpected response
- schema validation failure

Store the failure state and useful diagnostic information.

Do not expose raw exception traces to users.

Make it possible to retry a failed analysis from the UI or application layer.

Log enough information to diagnose failures without logging secrets.

## Cost/token control

Keep input deliberately concise.

Do not send all historical workouts.

Avoid duplicated text.

Send structured values instead of verbose prose wherever possible.

Keep the prompt stable so future prompt caching/optimisation is possible.

If token usage information is returned by the API, store or log it in a useful way so operating cost can later be measured.

## UI

Add an "AI Coaching" section to the completed workout view.

It should handle these states cleanly:

- analysis pending;
- analysis processing;
- analysis completed;
- analysis failed.

For completed analysis display:

- overall summary;
- feedback grouped by exercise;
- obvious progression/plateau status;
- recommended target for the next session;
- broader workout observations.

Fit this into the existing Haearn visual design rather than creating an unrelated UI style.

Do not dump raw JSON into the normal UI.

A developer/debug view of the structured response is acceptable if the project already has suitable admin/development tooling.

## Reanalysis

Provide a clean application-level mechanism for re-running analysis on an existing completed workout.

This might be a button or service action depending on the existing application design.

Reanalysis should create a traceable new analysis or version rather than silently replacing historical information, unless there is a good project-specific reason not to.

## Weekly review groundwork

Do not fully implement weekly coaching unless it naturally falls out of the architecture, but structure the code so a future feature can reuse:

- progression metric calculators;
- OpenAI client;
- structured-output handling;
- prompt/version management.

The future flow will resemble:

    WeeklyTrainingReviewJob
        ↓
    WeeklyContextBuilder
        ↓
    OpenAI
        ↓
    persisted WeeklyTrainingReview

Avoid designing the workout analysis so narrowly that this requires a rewrite.

## Tests

Add comprehensive automated tests using the project's existing framework.

At minimum test:

1. Completing a workout queues analysis.
2. The context builder produces the expected structured workout data.
3. Historical sessions are selected correctly.
4. Progression calculations work.
5. The OpenAI analyser sends the expected request structure.
6. Structured responses are persisted correctly.
7. API failures produce a failed analysis without affecting the workout.
8. Retried jobs do not create uncontrolled duplicates.
9. Missing historical data is handled.
10. Recommendations can contain nullable values.
11. The completed-workout UI displays pending/completed/failed states.

Do not call the real OpenAI API in the normal automated test suite.

Mock/stub only at the API boundary rather than mocking large portions of the application.

Use fixtures/factories representative of actual workout structures in Haearn.

## Developer tooling

Add a convenient development-only mechanism to analyse an existing workout manually.

For example, a Rails console/service invocation such as:

    Ai::WorkoutAnalyser.call(workout)

or an equivalent project-conventional interface.

If useful, add a rake task such as:

    bin/rails haearn:analyse_workout[123]

Do not add tooling just for its own sake if the existing application has a better mechanism.

## Documentation

Update the README or appropriate developer documentation with:

- required OpenAI configuration;
- environment variable/credential setup;
- architecture overview;
- how analysis is triggered;
- how to manually analyse a workout;
- how to retry failures;
- how to run relevant tests.

Do not place a real API key in documentation.

## Implementation approach

Work incrementally.

Before coding, give me a short summary of:

1. the existing workout/data model you found;
2. the workout-completion path;
3. the background-job mechanism;
4. the proposed files/database changes;
5. any assumptions you need to make.

Then implement the feature.

After implementation:

- run the relevant test suite;
- run linting/formatting used by the project;
- fix failures caused by the changes;
- show me the important files changed;
- explain any architectural decisions that are not obvious;
- identify sensible follow-up improvements separately rather than scope-creeping them into this implementation.

Do not rewrite unrelated parts of Haearn.

Prefer simple, idiomatic Rails code over introducing unnecessary frameworks or abstractions.
