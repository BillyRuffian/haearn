# Seed file for global exercises
# These are available to all users

puts "Seeding exercises..."

exercises = [
  # === COMPOUND LIFTS ===
  { name: "Barbell Bench Press", exercise_type: "reps", has_weight: true, description: "Flat bench press with barbell" },
  { name: "Incline Barbell Bench Press", exercise_type: "reps", has_weight: true, description: "Incline bench press with barbell" },
  { name: "Decline Barbell Bench Press", exercise_type: "reps", has_weight: true, description: "Decline bench press with barbell" },
  { name: "Barbell Back Squat", exercise_type: "reps", has_weight: true, description: "Back squat with barbell on traps" },
  { name: "Barbell Front Squat", exercise_type: "reps", has_weight: true, description: "Front squat with barbell on shoulders" },
  { name: "Conventional Deadlift", exercise_type: "reps", has_weight: true, description: "Deadlift with conventional stance" },
  { name: "Sumo Deadlift", exercise_type: "reps", has_weight: true, description: "Deadlift with wide sumo stance" },
  { name: "Romanian Deadlift", exercise_type: "reps", has_weight: true, description: "Stiff-leg deadlift focusing on hamstrings" },
  { name: "Overhead Press", exercise_type: "reps", has_weight: true, description: "Standing barbell press overhead" },
  { name: "Barbell Row", exercise_type: "reps", has_weight: true, description: "Bent-over barbell row" },
  { name: "Pendlay Row", exercise_type: "reps", has_weight: true, description: "Strict barbell row from floor each rep" },

  # === DUMBBELL EXERCISES ===
  { name: "Dumbbell Bench Press", exercise_type: "reps", has_weight: true, description: "Flat bench press with dumbbells" },
  { name: "Incline Dumbbell Bench Press", exercise_type: "reps", has_weight: true, description: "Incline bench press with dumbbells" },
  { name: "Dumbbell Shoulder Press", exercise_type: "reps", has_weight: true, description: "Seated or standing dumbbell press" },
  { name: "Dumbbell Row", exercise_type: "reps", has_weight: true, description: "Single-arm dumbbell row" },
  { name: "Dumbbell Lunges", exercise_type: "reps", has_weight: true, description: "Walking or stationary lunges" },
  { name: "Dumbbell Romanian Deadlift", exercise_type: "reps", has_weight: true, description: "RDL with dumbbells" },
  { name: "Goblet Squat", exercise_type: "reps", has_weight: true, description: "Squat holding dumbbell at chest" },
  { name: "Dumbbell Flyes", exercise_type: "reps", has_weight: true, description: "Flat or incline chest flyes" },
  { name: "Lateral Raises", exercise_type: "reps", has_weight: true, description: "Side delt raises with dumbbells" },
  { name: "Front Raises", exercise_type: "reps", has_weight: true, description: "Front delt raises with dumbbells" },
  { name: "Rear Delt Flyes", exercise_type: "reps", has_weight: true, description: "Bent-over rear delt flyes" },
  { name: "Dumbbell Bicep Curls", exercise_type: "reps", has_weight: true, description: "Standard bicep curls" },
  { name: "Hammer Curls", exercise_type: "reps", has_weight: true, description: "Neutral grip bicep curls" },
  { name: "Dumbbell Tricep Extensions", exercise_type: "reps", has_weight: true, description: "Overhead tricep extension" },
  { name: "Dumbbell Skull Crushers", exercise_type: "reps", has_weight: true, description: "Lying tricep extensions" },
  { name: "Dumbbell Shrugs", exercise_type: "reps", has_weight: true, description: "Trap shrugs with dumbbells" },

  # === CABLE EXERCISES ===
  { name: "Cable Crossover", exercise_type: "reps", has_weight: true, description: "High or low cable chest flyes" },
  { name: "Cable Tricep Pushdown", exercise_type: "reps", has_weight: true, description: "Tricep pushdowns with rope or bar" },
  { name: "Cable Bicep Curl", exercise_type: "reps", has_weight: true, description: "Bicep curls on cable machine" },
  { name: "Face Pulls", exercise_type: "reps", has_weight: true, description: "Rear delt and upper back cable pulls" },
  { name: "Cable Lateral Raises", exercise_type: "reps", has_weight: true, description: "Side delt raises on cables" },
  { name: "Cable Row", exercise_type: "reps", has_weight: true, description: "Seated cable row" },
  { name: "Lat Pulldown", exercise_type: "reps", has_weight: true, description: "Wide or close grip lat pulldown" },
  { name: "Straight Arm Pulldown", exercise_type: "reps", has_weight: true, description: "Lat isolation with straight arms" },
  { name: "Cable Crunch", exercise_type: "reps", has_weight: true, description: "Kneeling cable crunch for abs" },
  { name: "Cable Woodchop", exercise_type: "reps", has_weight: true, description: "Rotational core exercise" },
  { name: "Cable Pull Through", exercise_type: "reps", has_weight: true, description: "Hip hinge movement on cables" },
  { name: "Cable Kickbacks", exercise_type: "reps", has_weight: true, description: "Glute kickbacks on cables" },

  # === MACHINE EXERCISES ===
  { name: "Leg Press", exercise_type: "reps", has_weight: true, description: "45-degree leg press machine" },
  { name: "Hack Squat", exercise_type: "reps", has_weight: true, description: "Machine hack squat" },
  { name: "Leg Extension", exercise_type: "reps", has_weight: true, description: "Quad isolation machine" },
  { name: "Leg Curl", exercise_type: "reps", has_weight: true, description: "Seated or lying hamstring curl" },
  { name: "Calf Raise Machine", exercise_type: "reps", has_weight: true, description: "Standing or seated calf raises" },
  { name: "Chest Press Machine", exercise_type: "reps", has_weight: true, description: "Machine chest press" },
  { name: "Shoulder Press Machine", exercise_type: "reps", has_weight: true, description: "Machine shoulder press" },
  { name: "Pec Deck", exercise_type: "reps", has_weight: true, description: "Machine chest flyes" },
  { name: "Rear Delt Machine", exercise_type: "reps", has_weight: true, description: "Reverse pec deck" },
  { name: "Machine Row", exercise_type: "reps", has_weight: true, description: "Plate-loaded or cable row machine" },
  { name: "Hip Abduction", exercise_type: "reps", has_weight: true, description: "Outer thigh machine" },
  { name: "Hip Adduction", exercise_type: "reps", has_weight: true, description: "Inner thigh machine" },
  { name: "Assisted Pull-Up", exercise_type: "reps", has_weight: true, description: "Pull-ups with counterweight assistance" },
  { name: "Assisted Dip", exercise_type: "reps", has_weight: true, description: "Dips with counterweight assistance" },

  # === BODYWEIGHT EXERCISES ===
  { name: "Pull-Ups", exercise_type: "reps", has_weight: false, description: "Overhand grip pull-ups" },
  { name: "Chin-Ups", exercise_type: "reps", has_weight: false, description: "Underhand grip pull-ups" },
  { name: "Dips", exercise_type: "reps", has_weight: false, description: "Parallel bar dips" },
  { name: "Push-Ups", exercise_type: "reps", has_weight: false, description: "Standard push-ups" },
  { name: "Bodyweight Squats", exercise_type: "reps", has_weight: false, description: "Air squats" },
  { name: "Lunges", exercise_type: "reps", has_weight: false, description: "Bodyweight lunges" },
  { name: "Inverted Rows", exercise_type: "reps", has_weight: false, description: "Horizontal body rows" },
  { name: "Hanging Leg Raises", exercise_type: "reps", has_weight: false, description: "Ab exercise on pull-up bar" },
  { name: "Crunches", exercise_type: "reps", has_weight: false, description: "Basic ab crunches" },
  { name: "Russian Twists", exercise_type: "reps", has_weight: false, description: "Rotational ab exercise" },
  { name: "Mountain Climbers", exercise_type: "reps", has_weight: false, description: "Dynamic core and cardio" },
  { name: "Burpees", exercise_type: "reps", has_weight: false, description: "Full body conditioning" },

  # === WEIGHTED BODYWEIGHT ===
  { name: "Weighted Pull-Ups", exercise_type: "reps", has_weight: true, description: "Pull-ups with added weight" },
  { name: "Weighted Dips", exercise_type: "reps", has_weight: true, description: "Dips with added weight" },
  { name: "Weighted Push-Ups", exercise_type: "reps", has_weight: true, description: "Push-ups with plate on back" },

  # === KETTLEBELL EXERCISES ===
  { name: "Kettlebell Swing", exercise_type: "reps", has_weight: true, description: "Hip hinge swing movement" },
  { name: "Kettlebell Goblet Squat", exercise_type: "reps", has_weight: true, description: "Squat holding kettlebell" },
  { name: "Turkish Get-Up", exercise_type: "reps", has_weight: true, description: "Complex full-body movement" },
  { name: "Kettlebell Clean", exercise_type: "reps", has_weight: true, description: "Kettlebell clean to rack position" },
  { name: "Kettlebell Snatch", exercise_type: "reps", has_weight: true, description: "Single-arm overhead snatch" },

  # === TIME-BASED EXERCISES ===
  { name: "Plank", exercise_type: "time", has_weight: false, description: "Front plank hold" },
  { name: "Side Plank", exercise_type: "time", has_weight: false, description: "Side plank hold" },
  { name: "Dead Hang", exercise_type: "time", has_weight: false, description: "Passive hang from pull-up bar" },
  { name: "Wall Sit", exercise_type: "time", has_weight: false, description: "Isometric squat against wall" },
  { name: "L-Sit", exercise_type: "time", has_weight: false, description: "Isometric core hold" },
  { name: "Weighted Plank", exercise_type: "time", has_weight: true, description: "Plank with plate on back" },
  { name: "Farmer's Hold", exercise_type: "time", has_weight: true, description: "Static carry hold" },

  # === DISTANCE-BASED EXERCISES ===
  { name: "Farmer's Walk", exercise_type: "distance", has_weight: true, description: "Walking carry with weights" },
  { name: "Sled Push", exercise_type: "distance", has_weight: true, description: "Pushing weighted sled" },
  { name: "Sled Pull", exercise_type: "distance", has_weight: true, description: "Pulling weighted sled" },
  { name: "Yoke Walk", exercise_type: "distance", has_weight: true, description: "Walking with yoke on back" },
  { name: "Sandbag Carry", exercise_type: "distance", has_weight: true, description: "Carrying sandbag" },
  { name: "Walking Lunges", exercise_type: "distance", has_weight: true, description: "Lunges for distance" },

  # === BARBELL VARIATIONS ===
  { name: "Close Grip Bench Press", exercise_type: "reps", has_weight: true, description: "Tricep-focused bench press" },
  { name: "Barbell Curl", exercise_type: "reps", has_weight: true, description: "Standing barbell bicep curl" },
  { name: "EZ Bar Curl", exercise_type: "reps", has_weight: true, description: "Bicep curl with EZ curl bar" },
  { name: "Skull Crushers", exercise_type: "reps", has_weight: true, description: "Lying barbell tricep extensions" },
  { name: "Good Mornings", exercise_type: "reps", has_weight: true, description: "Barbell hip hinge for posterior chain" },
  { name: "Barbell Shrugs", exercise_type: "reps", has_weight: true, description: "Trap shrugs with barbell" },
  { name: "Hip Thrust", exercise_type: "reps", has_weight: true, description: "Barbell hip thrust for glutes" },
  { name: "Barbell Lunge", exercise_type: "reps", has_weight: true, description: "Lunges with barbell on back" },
  { name: "Bulgarian Split Squat", exercise_type: "reps", has_weight: true, description: "Rear foot elevated split squat" },
  { name: "Zercher Squat", exercise_type: "reps", has_weight: true, description: "Squat with bar in elbow crease" },
  { name: "Power Clean", exercise_type: "reps", has_weight: true, description: "Olympic lift - clean to shoulders" },
  { name: "Hang Clean", exercise_type: "reps", has_weight: true, description: "Clean from hang position" },
  { name: "Push Press", exercise_type: "reps", has_weight: true, description: "Overhead press with leg drive" },

  # === SMITH MACHINE ===
  { name: "Smith Machine Squat", exercise_type: "reps", has_weight: true, description: "Squat on Smith machine" },
  { name: "Smith Machine Bench Press", exercise_type: "reps", has_weight: true, description: "Bench press on Smith machine" },
  { name: "Smith Machine Shoulder Press", exercise_type: "reps", has_weight: true, description: "Overhead press on Smith machine" },
  { name: "Smith Machine Row", exercise_type: "reps", has_weight: true, description: "Bent-over row on Smith machine" }
]

exercises.each do |exercise_attrs|
  Exercise.find_or_create_by!(name: exercise_attrs[:name]) do |exercise|
    exercise.exercise_type = exercise_attrs[:exercise_type]
    exercise.has_weight = exercise_attrs[:has_weight]
    exercise.description = exercise_attrs[:description]
    exercise.user_id = nil # Global exercise
  end
end

puts "Created #{Exercise.count} exercises"
