load Rails.root.join("db/seeds/exercise_catalog.rb")

puts "Seeding exercises..."

ExerciseSeedCatalog::EXERCISES.each do |exercise_attrs|
  exercise = Exercise.find_or_initialize_by(name: exercise_attrs[:name])
  exercise.exercise_type = exercise_attrs[:exercise_type]
  exercise.has_weight = exercise_attrs[:has_weight]
  exercise.description = exercise_attrs[:description]
  exercise.primary_muscle_group = exercise_attrs[:primary_muscle_group]
  exercise.user_id = nil # Global exercise
  exercise.save!
end

ExerciseSeedCatalog::DEPRECATED_ALIASES.each do |deprecated_name, canonical_name|
  duplicate = Exercise.global.find_by(name: deprecated_name)
  target = Exercise.global.find_by(name: canonical_name)
  next unless duplicate && target

  result = ExerciseMerger.call(target: target, duplicate: duplicate)
  puts result.message if result.success?
  puts "Skipped merge #{deprecated_name} -> #{canonical_name}: #{result.message}" unless result.success?
end

puts "Created/Updated #{Exercise.count} exercises"
