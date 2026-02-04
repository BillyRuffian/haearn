# Seed file for global exercises
# These are available to all users

puts "Seeding exercises..."

exercises = [
  # === COMPOUND LIFTS ===
  { name: "Barbell Bench Press", exercise_type: "reps", has_weight: true, description: "Flat bench press with barbell", primary_muscle_group: "chest" },
  { name: "Incline Barbell Bench Press", exercise_type: "reps", has_weight: true, description: "Incline bench press with barbell", primary_muscle_group: "chest" },
  { name: "Decline Barbell Bench Press", exercise_type: "reps", has_weight: true, description: "Decline bench press with barbell", primary_muscle_group: "chest" },
  { name: "Barbell Back Squat", exercise_type: "reps", has_weight: true, description: "Back squat with barbell on traps", primary_muscle_group: "quadriceps" },
  { name: "Barbell Front Squat", exercise_type: "reps", has_weight: true, description: "Front squat with barbell on shoulders", primary_muscle_group: "quadriceps" },
  { name: "Conventional Deadlift", exercise_type: "reps", has_weight: true, description: "Deadlift with conventional stance", primary_muscle_group: "back" },
  { name: "Sumo Deadlift", exercise_type: "reps", has_weight: true, description: "Deadlift with wide sumo stance", primary_muscle_group: "glutes" },
  { name: "Romanian Deadlift", exercise_type: "reps", has_weight: true, description: "Stiff-leg deadlift focusing on hamstrings", primary_muscle_group: "hamstrings" },
  { name: "Overhead Press", exercise_type: "reps", has_weight: true, description: "Standing barbell press overhead", primary_muscle_group: "shoulders" },
  { name: "Barbell Row", exercise_type: "reps", has_weight: true, description: "Bent-over barbell row", primary_muscle_group: "back" },
  { name: "Pendlay Row", exercise_type: "reps", has_weight: true, description: "Strict barbell row from floor each rep", primary_muscle_group: "back" },

  # === DUMBBELL EXERCISES ===
  { name: "Dumbbell Bench Press", exercise_type: "reps", has_weight: true, description: "Flat bench press with dumbbells", primary_muscle_group: "chest" },
  { name: "Incline Dumbbell Bench Press", exercise_type: "reps", has_weight: true, description: "Incline bench press with dumbbells", primary_muscle_group: "chest" },
  { name: "Dumbbell Shoulder Press", exercise_type: "reps", has_weight: true, description: "Seated or standing dumbbell press", primary_muscle_group: "shoulders" },
  { name: "Dumbbell Row", exercise_type: "reps", has_weight: true, description: "Single-arm dumbbell row", primary_muscle_group: "back" },
  { name: "Dumbbell Lunges", exercise_type: "reps", has_weight: true, description: "Walking or stationary lunges", primary_muscle_group: "quadriceps" },
  { name: "Dumbbell Romanian Deadlift", exercise_type: "reps", has_weight: true, description: "RDL with dumbbells", primary_muscle_group: "hamstrings" },
  { name: "Goblet Squat", exercise_type: "reps", has_weight: true, description: "Squat holding dumbbell at chest", primary_muscle_group: "quadriceps" },
  { name: "Dumbbell Flyes", exercise_type: "reps", has_weight: true, description: "Flat or incline chest flyes", primary_muscle_group: "chest" },
  { name: "Lateral Raises", exercise_type: "reps", has_weight: true, description: "Side delt raises with dumbbells", primary_muscle_group: "shoulders" },
  { name: "Front Raises", exercise_type: "reps", has_weight: true, description: "Front delt raises with dumbbells", primary_muscle_group: "shoulders" },
  { name: "Rear Delt Flyes", exercise_type: "reps", has_weight: true, description: "Bent-over rear delt flyes", primary_muscle_group: "shoulders" },
  { name: "Dumbbell Bicep Curls", exercise_type: "reps", has_weight: true, description: "Standard bicep curls", primary_muscle_group: "biceps" },
  { name: "Hammer Curls", exercise_type: "reps", has_weight: true, description: "Neutral grip bicep curls", primary_muscle_group: "biceps" },
  { name: "Dumbbell Tricep Extensions", exercise_type: "reps", has_weight: true, description: "Overhead tricep extension", primary_muscle_group: "triceps" },
  { name: "Dumbbell Skull Crushers", exercise_type: "reps", has_weight: true, description: "Lying tricep extensions", primary_muscle_group: "triceps" },
  { name: "Dumbbell Shrugs", exercise_type: "reps", has_weight: true, description: "Trap shrugs with dumbbells", primary_muscle_group: "back" },

  # === CABLE EXERCISES ===
  { name: "Cable Crossover", exercise_type: "reps", has_weight: true, description: "High or low cable chest flyes", primary_muscle_group: "chest" },
  { name: "Cable Tricep Pushdown", exercise_type: "reps", has_weight: true, description: "Tricep pushdowns with rope or bar", primary_muscle_group: "triceps" },
  { name: "Cable Bicep Curl", exercise_type: "reps", has_weight: true, description: "Bicep curls on cable machine", primary_muscle_group: "biceps" },
  { name: "Face Pulls", exercise_type: "reps", has_weight: true, description: "Rear delt and upper back cable pulls", primary_muscle_group: "shoulders" },
  { name: "Cable Lateral Raises", exercise_type: "reps", has_weight: true, description: "Side delt raises on cables", primary_muscle_group: "shoulders" },
  { name: "Cable Row", exercise_type: "reps", has_weight: true, description: "Seated cable row", primary_muscle_group: "back" },
  { name: "Lat Pulldown", exercise_type: "reps", has_weight: true, description: "Wide or close grip lat pulldown", primary_muscle_group: "back" },
  { name: "Straight Arm Pulldown", exercise_type: "reps", has_weight: true, description: "Lat isolation with straight arms", primary_muscle_group: "back" },
  { name: "Cable Crunch", exercise_type: "reps", has_weight: true, description: "Kneeling cable crunch for abs", primary_muscle_group: "core" },
  { name: "Cable Woodchop", exercise_type: "reps", has_weight: true, description: "Rotational core exercise", primary_muscle_group: "core" },
  { name: "Cable Pull Through", exercise_type: "reps", has_weight: true, description: "Hip hinge movement on cables", primary_muscle_group: "glutes" },
  { name: "Cable Kickbacks", exercise_type: "reps", has_weight: true, description: "Glute kickbacks on cables", primary_muscle_group: "glutes" },

  # === MACHINE EXERCISES ===
  { name: "Leg Press", exercise_type: "reps", has_weight: true, description: "45-degree leg press machine", primary_muscle_group: "quadriceps" },
  { name: "Hack Squat", exercise_type: "reps", has_weight: true, description: "Machine hack squat", primary_muscle_group: "quadriceps" },
  { name: "Leg Extension", exercise_type: "reps", has_weight: true, description: "Quad isolation machine", primary_muscle_group: "quadriceps" },
  { name: "Leg Curl", exercise_type: "reps", has_weight: true, description: "Seated or lying hamstring curl", primary_muscle_group: "hamstrings" },
  { name: "Calf Raise Machine", exercise_type: "reps", has_weight: true, description: "Standing or seated calf raises", primary_muscle_group: "calves" },
  { name: "Chest Press Machine", exercise_type: "reps", has_weight: true, description: "Machine chest press", primary_muscle_group: "chest" },
  { name: "Shoulder Press Machine", exercise_type: "reps", has_weight: true, description: "Machine shoulder press", primary_muscle_group: "shoulders" },
  { name: "Pec Deck", exercise_type: "reps", has_weight: true, description: "Machine chest flyes", primary_muscle_group: "chest" },
  { name: "Rear Delt Machine", exercise_type: "reps", has_weight: true, description: "Reverse pec deck", primary_muscle_group: "shoulders" },
  { name: "Machine Row", exercise_type: "reps", has_weight: true, description: "Plate-loaded or cable row machine", primary_muscle_group: "back" },
  { name: "Hip Abduction", exercise_type: "reps", has_weight: true, description: "Outer thigh machine", primary_muscle_group: "glutes" },
  { name: "Hip Adduction", exercise_type: "reps", has_weight: true, description: "Inner thigh machine", primary_muscle_group: "quadriceps" },
  { name: "Assisted Pull-Up", exercise_type: "reps", has_weight: true, description: "Pull-ups with counterweight assistance", primary_muscle_group: "back" },
  { name: "Assisted Dip", exercise_type: "reps", has_weight: true, description: "Dips with counterweight assistance", primary_muscle_group: "chest" },

  # === BODYWEIGHT EXERCISES ===
  { name: "Pull-Ups", exercise_type: "reps", has_weight: false, description: "Overhand grip pull-ups", primary_muscle_group: "back" },
  { name: "Chin-Ups", exercise_type: "reps", has_weight: false, description: "Underhand grip pull-ups", primary_muscle_group: "back" },
  { name: "Dips", exercise_type: "reps", has_weight: false, description: "Parallel bar dips", primary_muscle_group: "chest" },
  { name: "Push-Ups", exercise_type: "reps", has_weight: false, description: "Standard push-ups", primary_muscle_group: "chest" },
  { name: "Bodyweight Squats", exercise_type: "reps", has_weight: false, description: "Air squats", primary_muscle_group: "quadriceps" },
  { name: "Lunges", exercise_type: "reps", has_weight: false, description: "Bodyweight lunges", primary_muscle_group: "quadriceps" },
  { name: "Inverted Rows", exercise_type: "reps", has_weight: false, description: "Horizontal body rows", primary_muscle_group: "back" },
  { name: "Hanging Leg Raises", exercise_type: "reps", has_weight: false, description: "Ab exercise on pull-up bar", primary_muscle_group: "core" },
  { name: "Crunches", exercise_type: "reps", has_weight: false, description: "Basic ab crunches", primary_muscle_group: "core" },
  { name: "Russian Twists", exercise_type: "reps", has_weight: false, description: "Rotational ab exercise", primary_muscle_group: "core" },
  { name: "Mountain Climbers", exercise_type: "reps", has_weight: false, description: "Dynamic core and cardio", primary_muscle_group: "core" },
  { name: "Burpees", exercise_type: "reps", has_weight: false, description: "Full body conditioning", primary_muscle_group: "full_body" },

  # === WEIGHTED BODYWEIGHT ===
  { name: "Weighted Pull-Ups", exercise_type: "reps", has_weight: true, description: "Pull-ups with added weight", primary_muscle_group: "back" },
  { name: "Weighted Dips", exercise_type: "reps", has_weight: true, description: "Dips with added weight", primary_muscle_group: "chest" },
  { name: "Weighted Push-Ups", exercise_type: "reps", has_weight: true, description: "Push-ups with plate on back", primary_muscle_group: "chest" },

  # === KETTLEBELL EXERCISES ===
  { name: "Kettlebell Swing", exercise_type: "reps", has_weight: true, description: "Hip hinge swing movement", primary_muscle_group: "glutes" },
  { name: "Kettlebell Goblet Squat", exercise_type: "reps", has_weight: true, description: "Squat holding kettlebell", primary_muscle_group: "quadriceps" },
  { name: "Turkish Get-Up", exercise_type: "reps", has_weight: true, description: "Complex full-body movement", primary_muscle_group: "full_body" },
  { name: "Kettlebell Clean", exercise_type: "reps", has_weight: true, description: "Kettlebell clean to rack position", primary_muscle_group: "full_body" },
  { name: "Kettlebell Snatch", exercise_type: "reps", has_weight: true, description: "Single-arm overhead snatch", primary_muscle_group: "full_body" },

  # === TIME-BASED EXERCISES ===
  { name: "Plank", exercise_type: "time", has_weight: false, description: "Front plank hold", primary_muscle_group: "core" },
  { name: "Side Plank", exercise_type: "time", has_weight: false, description: "Side plank hold", primary_muscle_group: "core" },
  { name: "Dead Hang", exercise_type: "time", has_weight: false, description: "Passive hang from pull-up bar", primary_muscle_group: "forearms" },
  { name: "Wall Sit", exercise_type: "time", has_weight: false, description: "Isometric squat against wall", primary_muscle_group: "quadriceps" },
  { name: "L-Sit", exercise_type: "time", has_weight: false, description: "Isometric core hold", primary_muscle_group: "core" },
  { name: "Weighted Plank", exercise_type: "time", has_weight: true, description: "Plank with plate on back", primary_muscle_group: "core" },
  { name: "Farmer's Hold", exercise_type: "time", has_weight: true, description: "Static carry hold", primary_muscle_group: "forearms" },

  # === DISTANCE-BASED EXERCISES ===
  { name: "Farmer's Walk", exercise_type: "distance", has_weight: true, description: "Walking carry with weights", primary_muscle_group: "forearms" },
  { name: "Sled Push", exercise_type: "distance", has_weight: true, description: "Pushing weighted sled", primary_muscle_group: "quadriceps" },
  { name: "Sled Pull", exercise_type: "distance", has_weight: true, description: "Pulling weighted sled", primary_muscle_group: "back" },
  { name: "Yoke Walk", exercise_type: "distance", has_weight: true, description: "Walking with yoke on back", primary_muscle_group: "full_body" },
  { name: "Sandbag Carry", exercise_type: "distance", has_weight: true, description: "Carrying sandbag", primary_muscle_group: "full_body" },
  { name: "Walking Lunges", exercise_type: "distance", has_weight: true, description: "Lunges for distance", primary_muscle_group: "quadriceps" },

  # === BARBELL VARIATIONS ===
  { name: "Close Grip Bench Press", exercise_type: "reps", has_weight: true, description: "Tricep-focused bench press", primary_muscle_group: "triceps" },
  { name: "Barbell Curl", exercise_type: "reps", has_weight: true, description: "Standing barbell bicep curl", primary_muscle_group: "biceps" },
  { name: "EZ Bar Curl", exercise_type: "reps", has_weight: true, description: "Bicep curl with EZ curl bar", primary_muscle_group: "biceps" },
  { name: "Skull Crushers", exercise_type: "reps", has_weight: true, description: "Lying barbell tricep extensions", primary_muscle_group: "triceps" },
  { name: "Good Mornings", exercise_type: "reps", has_weight: true, description: "Barbell hip hinge for posterior chain", primary_muscle_group: "hamstrings" },
  { name: "Barbell Shrugs", exercise_type: "reps", has_weight: true, description: "Trap shrugs with barbell", primary_muscle_group: "back" },
  { name: "Hip Thrust", exercise_type: "reps", has_weight: true, description: "Barbell hip thrust for glutes", primary_muscle_group: "glutes" },
  { name: "Barbell Lunge", exercise_type: "reps", has_weight: true, description: "Lunges with barbell on back", primary_muscle_group: "quadriceps" },
  { name: "Bulgarian Split Squat", exercise_type: "reps", has_weight: true, description: "Rear foot elevated split squat", primary_muscle_group: "quadriceps" },
  { name: "Zercher Squat", exercise_type: "reps", has_weight: true, description: "Squat with bar in elbow crease", primary_muscle_group: "quadriceps" },
  { name: "Power Clean", exercise_type: "reps", has_weight: true, description: "Olympic lift - clean to shoulders", primary_muscle_group: "full_body" },
  { name: "Hang Clean", exercise_type: "reps", has_weight: true, description: "Clean from hang position", primary_muscle_group: "full_body" },
  { name: "Push Press", exercise_type: "reps", has_weight: true, description: "Overhead press with leg drive", primary_muscle_group: "shoulders" },

  # === SMITH MACHINE ===
  { name: "Smith Machine Squat", exercise_type: "reps", has_weight: true, description: "Squat on Smith machine", primary_muscle_group: "quadriceps" },
  { name: "Smith Machine Bench Press", exercise_type: "reps", has_weight: true, description: "Bench press on Smith machine", primary_muscle_group: "chest" },
  { name: "Smith Machine Shoulder Press", exercise_type: "reps", has_weight: true, description: "Overhead press on Smith machine", primary_muscle_group: "shoulders" },
  { name: "Smith Machine Row", exercise_type: "reps", has_weight: true, description: "Bent-over row on Smith machine", primary_muscle_group: "back" }
]

exercises.each do |exercise_attrs|
  exercise = Exercise.find_or_initialize_by(name: exercise_attrs[:name])
  exercise.exercise_type = exercise_attrs[:exercise_type]
  exercise.has_weight = exercise_attrs[:has_weight]
  exercise.description = exercise_attrs[:description]
  exercise.primary_muscle_group = exercise_attrs[:primary_muscle_group]
  exercise.user_id = nil # Global exercise
  exercise.save!
end

puts "Created/Updated #{Exercise.count} exercises"
