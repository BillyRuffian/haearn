# Canonical global exercise catalog.
# Exercise names should describe the movement pattern, not the equipment used.
# Equipment-specific seeded names that previously existed are kept below as
# deprecated aliases so reseeding can merge them into the canonical exercise.
module ExerciseSeedCatalog
  EXERCISES = [
    # === COMPOUND LIFTS ===
    { name: "Bench Press", exercise_type: "reps", has_weight: true, description: "Flat horizontal press", primary_muscle_group: "chest" },
    { name: "Incline Bench Press", exercise_type: "reps", has_weight: true, description: "Incline horizontal press", primary_muscle_group: "chest" },
    { name: "Decline Bench Press", exercise_type: "reps", has_weight: true, description: "Decline horizontal press", primary_muscle_group: "chest" },
    { name: "Back Squat", exercise_type: "reps", has_weight: true, description: "Back-loaded squat pattern", primary_muscle_group: "quadriceps" },
    { name: "Front Squat", exercise_type: "reps", has_weight: true, description: "Front-loaded squat pattern", primary_muscle_group: "quadriceps" },
    { name: "Conventional Deadlift", exercise_type: "reps", has_weight: true, description: "Deadlift with conventional stance", primary_muscle_group: "back" },
    { name: "Sumo Deadlift", exercise_type: "reps", has_weight: true, description: "Deadlift with wide sumo stance", primary_muscle_group: "glutes" },
    { name: "Romanian Deadlift", exercise_type: "reps", has_weight: true, description: "Hip hinge emphasizing hamstrings", primary_muscle_group: "hamstrings" },
    { name: "Overhead Press", exercise_type: "reps", has_weight: true, description: "Vertical overhead press", primary_muscle_group: "shoulders" },
    { name: "Bent-Over Row", exercise_type: "reps", has_weight: true, description: "Hip-hinged horizontal row", primary_muscle_group: "back" },
    { name: "Pendlay Row", exercise_type: "reps", has_weight: true, description: "Strict row from the floor each rep", primary_muscle_group: "back" },

    # === UPPER / LOWER ACCESSORIES ===
    { name: "Shoulder Press", exercise_type: "reps", has_weight: true, description: "Seated or standing vertical press", primary_muscle_group: "shoulders" },
    { name: "One-Arm Row", exercise_type: "reps", has_weight: true, description: "Single-arm row variation", primary_muscle_group: "back" },
    { name: "Weighted Lunges", exercise_type: "reps", has_weight: true, description: "Walking or stationary lunges with load", primary_muscle_group: "quadriceps" },
    { name: "Goblet Squat", exercise_type: "reps", has_weight: true, description: "Squat holding a load at the chest", primary_muscle_group: "quadriceps" },
    { name: "Chest Flyes", exercise_type: "reps", has_weight: true, description: "Horizontal chest fly variation", primary_muscle_group: "chest" },
    { name: "Lateral Raises", exercise_type: "reps", has_weight: true, description: "Side delt raise variation", primary_muscle_group: "shoulders" },
    { name: "Front Raises", exercise_type: "reps", has_weight: true, description: "Front delt raise variation", primary_muscle_group: "shoulders" },
    { name: "Rear Delt Flyes", exercise_type: "reps", has_weight: true, description: "Rear delt fly variation", primary_muscle_group: "shoulders" },
    { name: "Bicep Curl", exercise_type: "reps", has_weight: true, description: "Standard curl pattern", primary_muscle_group: "biceps" },
    { name: "Hammer Curls", exercise_type: "reps", has_weight: true, description: "Neutral-grip curl variation", primary_muscle_group: "biceps" },
    { name: "Overhead Tricep Extension", exercise_type: "reps", has_weight: true, description: "Overhead elbow extension", primary_muscle_group: "triceps" },
    { name: "Skull Crushers", exercise_type: "reps", has_weight: true, description: "Lying elbow extension", primary_muscle_group: "triceps" },
    { name: "Shrugs", exercise_type: "reps", has_weight: true, description: "Trap shrug variation", primary_muscle_group: "back" },

    # === CABLE / MACHINE FRIENDLY MOVEMENTS ===
    { name: "Cable Crossover", exercise_type: "reps", has_weight: true, description: "Cable chest fly variation", primary_muscle_group: "chest" },
    { name: "Tricep Pushdown", exercise_type: "reps", has_weight: true, description: "Pushdown variation", primary_muscle_group: "triceps" },
    { name: "Face Pulls", exercise_type: "reps", has_weight: true, description: "Rear delt and upper back pull variation", primary_muscle_group: "shoulders" },
    { name: "Seated Row", exercise_type: "reps", has_weight: true, description: "Seated horizontal row variation", primary_muscle_group: "back" },
    { name: "Lat Pulldown", exercise_type: "reps", has_weight: true, description: "Vertical pull-down variation", primary_muscle_group: "back" },
    { name: "Straight Arm Pulldown", exercise_type: "reps", has_weight: true, description: "Lat isolation with straight arms", primary_muscle_group: "back" },
    { name: "Cable Crunch", exercise_type: "reps", has_weight: true, description: "Kneeling weighted crunch", primary_muscle_group: "core" },
    { name: "Cable Woodchop", exercise_type: "reps", has_weight: true, description: "Rotational core exercise", primary_muscle_group: "core" },
    { name: "Cable Pull Through", exercise_type: "reps", has_weight: true, description: "Cable hip hinge", primary_muscle_group: "glutes" },
    { name: "Cable Kickbacks", exercise_type: "reps", has_weight: true, description: "Cable glute kickback", primary_muscle_group: "glutes" },

    # === MACHINE MOVEMENTS ===
    { name: "Leg Press", exercise_type: "reps", has_weight: true, description: "Leg press variation", primary_muscle_group: "quadriceps" },
    { name: "Hack Squat", exercise_type: "reps", has_weight: true, description: "Hack squat variation", primary_muscle_group: "quadriceps" },
    { name: "Leg Extension", exercise_type: "reps", has_weight: true, description: "Knee extension isolation", primary_muscle_group: "quadriceps" },
    { name: "Leg Curl", exercise_type: "reps", has_weight: true, description: "Hamstring curl variation", primary_muscle_group: "hamstrings" },
    { name: "Calf Raise", exercise_type: "reps", has_weight: true, description: "Standing or seated calf raise", primary_muscle_group: "calves" },
    { name: "Chest Press", exercise_type: "reps", has_weight: true, description: "Seated chest press variation", primary_muscle_group: "chest" },
    { name: "Pec Deck", exercise_type: "reps", has_weight: true, description: "Machine chest fly variation", primary_muscle_group: "chest" },
    { name: "Hip Abduction", exercise_type: "reps", has_weight: true, description: "Outer thigh machine variation", primary_muscle_group: "glutes" },
    { name: "Hip Adduction", exercise_type: "reps", has_weight: true, description: "Inner thigh machine variation", primary_muscle_group: "quadriceps" },
    { name: "Assisted Pull-Up", exercise_type: "reps", has_weight: true, description: "Pull-up with counterweight assistance", primary_muscle_group: "back" },
    { name: "Assisted Dip", exercise_type: "reps", has_weight: true, description: "Dip with counterweight assistance", primary_muscle_group: "chest" },

    # === BODYWEIGHT EXERCISES ===
    { name: "Pull-Ups", exercise_type: "reps", has_weight: false, description: "Overhand grip pull-ups", primary_muscle_group: "back" },
    { name: "Chin-Ups", exercise_type: "reps", has_weight: false, description: "Underhand grip pull-ups", primary_muscle_group: "back" },
    { name: "Dips", exercise_type: "reps", has_weight: false, description: "Parallel bar dips", primary_muscle_group: "chest" },
    { name: "Push-Ups", exercise_type: "reps", has_weight: false, description: "Standard push-ups", primary_muscle_group: "chest" },
    { name: "Bodyweight Squats", exercise_type: "reps", has_weight: false, description: "Air squats", primary_muscle_group: "quadriceps" },
    { name: "Lunges", exercise_type: "reps", has_weight: false, description: "Bodyweight lunges", primary_muscle_group: "quadriceps" },
    { name: "Inverted Rows", exercise_type: "reps", has_weight: false, description: "Horizontal body rows", primary_muscle_group: "back" },
    { name: "Hanging Leg Raises", exercise_type: "reps", has_weight: false, description: "Hanging ab raise", primary_muscle_group: "core" },
    { name: "Crunches", exercise_type: "reps", has_weight: false, description: "Basic ab crunches", primary_muscle_group: "core" },
    { name: "Russian Twists", exercise_type: "reps", has_weight: false, description: "Rotational ab exercise", primary_muscle_group: "core" },
    { name: "Mountain Climbers", exercise_type: "reps", has_weight: false, description: "Dynamic core and cardio", primary_muscle_group: "core" },
    { name: "Burpees", exercise_type: "reps", has_weight: false, description: "Full body conditioning", primary_muscle_group: "full_body" },

    # === WEIGHTED BODYWEIGHT ===
    { name: "Weighted Pull-Ups", exercise_type: "reps", has_weight: true, description: "Pull-ups with added weight", primary_muscle_group: "back" },
    { name: "Weighted Dips", exercise_type: "reps", has_weight: true, description: "Dips with added weight", primary_muscle_group: "chest" },
    { name: "Weighted Push-Ups", exercise_type: "reps", has_weight: true, description: "Push-ups with added load", primary_muscle_group: "chest" },

    # === KETTLEBELL / STRONGMAN ===
    { name: "Kettlebell Swing", exercise_type: "reps", has_weight: true, description: "Kettlebell swing", primary_muscle_group: "glutes" },
    { name: "Turkish Get-Up", exercise_type: "reps", has_weight: true, description: "Complex full-body movement", primary_muscle_group: "full_body" },
    { name: "Kettlebell Clean", exercise_type: "reps", has_weight: true, description: "Kettlebell clean to rack position", primary_muscle_group: "full_body" },
    { name: "Kettlebell Snatch", exercise_type: "reps", has_weight: true, description: "Single-arm overhead snatch", primary_muscle_group: "full_body" },

    # === TIME-BASED EXERCISES ===
    { name: "Plank", exercise_type: "time", has_weight: false, description: "Front plank hold", primary_muscle_group: "core" },
    { name: "Side Plank", exercise_type: "time", has_weight: false, description: "Side plank hold", primary_muscle_group: "core" },
    { name: "Dead Hang", exercise_type: "time", has_weight: false, description: "Passive hang from pull-up bar", primary_muscle_group: "forearms" },
    { name: "Wall Sit", exercise_type: "time", has_weight: false, description: "Isometric squat against wall", primary_muscle_group: "quadriceps" },
    { name: "L-Sit", exercise_type: "time", has_weight: false, description: "Isometric core hold", primary_muscle_group: "core" },
    { name: "Weighted Plank", exercise_type: "time", has_weight: true, description: "Plank with added load", primary_muscle_group: "core" },
    { name: "Farmer's Hold", exercise_type: "time", has_weight: true, description: "Static carry hold", primary_muscle_group: "forearms" },

    # === DISTANCE-BASED EXERCISES ===
    { name: "Farmer's Walk", exercise_type: "distance", has_weight: true, description: "Walking carry with weights", primary_muscle_group: "forearms" },
    { name: "Sled Push", exercise_type: "distance", has_weight: true, description: "Pushing a weighted sled", primary_muscle_group: "quadriceps" },
    { name: "Sled Pull", exercise_type: "distance", has_weight: true, description: "Pulling a weighted sled", primary_muscle_group: "back" },
    { name: "Yoke Walk", exercise_type: "distance", has_weight: true, description: "Walking with a yoke on the back", primary_muscle_group: "full_body" },
    { name: "Sandbag Carry", exercise_type: "distance", has_weight: true, description: "Carrying a sandbag", primary_muscle_group: "full_body" },
    { name: "Walking Lunges", exercise_type: "distance", has_weight: true, description: "Lunges for distance", primary_muscle_group: "quadriceps" },

    # === BARBELL / LOADED VARIATIONS ===
    { name: "Close Grip Bench Press", exercise_type: "reps", has_weight: true, description: "Tricep-focused bench press", primary_muscle_group: "triceps" },
    { name: "Good Mornings", exercise_type: "reps", has_weight: true, description: "Loaded hip hinge for posterior chain", primary_muscle_group: "hamstrings" },
    { name: "Hip Thrust", exercise_type: "reps", has_weight: true, description: "Hip thrust variation", primary_muscle_group: "glutes" },
    { name: "Bulgarian Split Squat", exercise_type: "reps", has_weight: true, description: "Rear foot elevated split squat", primary_muscle_group: "quadriceps" },
    { name: "Zercher Squat", exercise_type: "reps", has_weight: true, description: "Squat with load in the elbow crease", primary_muscle_group: "quadriceps" },
    { name: "Power Clean", exercise_type: "reps", has_weight: true, description: "Clean to the shoulders", primary_muscle_group: "full_body" },
    { name: "Hang Clean", exercise_type: "reps", has_weight: true, description: "Clean from the hang position", primary_muscle_group: "full_body" },
    { name: "Push Press", exercise_type: "reps", has_weight: true, description: "Overhead press with leg drive", primary_muscle_group: "shoulders" }
  ].freeze

  DEPRECATED_ALIASES = {
    "Barbell Back Squat" => "Back Squat",
    "Barbell Front Squat" => "Front Squat",
    "Barbell Row" => "Bent-Over Row",
    "Dumbbell Bench Press" => "Bench Press",
    "Incline Dumbbell Bench Press" => "Incline Bench Press",
    "Dumbbell Shoulder Press" => "Shoulder Press",
    "Dumbbell Row" => "One-Arm Row",
    "Dumbbell Lunges" => "Weighted Lunges",
    "Dumbbell Romanian Deadlift" => "Romanian Deadlift",
    "Dumbbell Flyes" => "Chest Flyes",
    "Dumbbell Bicep Curls" => "Bicep Curl",
    "Dumbbell Tricep Extensions" => "Overhead Tricep Extension",
    "Dumbbell Skull Crushers" => "Skull Crushers",
    "Dumbbell Shrugs" => "Shrugs",
    "Cable Tricep Pushdown" => "Tricep Pushdown",
    "Cable Bicep Curl" => "Bicep Curl",
    "Cable Lateral Raises" => "Lateral Raises",
    "Cable Row" => "Seated Row",
    "Calf Raise Machine" => "Calf Raise",
    "Chest Press Machine" => "Chest Press",
    "Shoulder Press Machine" => "Shoulder Press",
    "Rear Delt Machine" => "Rear Delt Flyes",
    "Machine Row" => "Seated Row",
    "Kettlebell Goblet Squat" => "Goblet Squat",
    "Barbell Curl" => "Bicep Curl",
    "EZ Bar Curl" => "Bicep Curl",
    "Barbell Shrugs" => "Shrugs",
    "Barbell Lunge" => "Weighted Lunges",
    "Smith Machine Squat" => "Back Squat",
    "Smith Machine Bench Press" => "Bench Press",
    "Smith Machine Shoulder Press" => "Shoulder Press",
    "Smith Machine Row" => "Bent-Over Row"
  }.freeze
end
