require 'spec_helper'
require_relative '../../db/seeds/exercise_catalog'

RSpec.describe ExerciseSeedCatalog do
  describe 'deprecated aliases' do
    it 'always point at canonical seeded exercises' do
      canonical_names = described_class::EXERCISES.map { |attrs| attrs[:name] }

      described_class::DEPRECATED_ALIASES.each_value do |target_name|
        expect(canonical_names).to include(target_name)
      end
    end
  end

  describe 'canonical exercise names' do
    it 'does not keep obvious equipment-prefixed duplicates' do
      canonical_names = described_class::EXERCISES.map { |attrs| attrs[:name] }

      [
        'Dumbbell Bench Press',
        'Incline Dumbbell Bench Press',
        'Dumbbell Romanian Deadlift',
        'Kettlebell Goblet Squat',
        'Smith Machine Bench Press'
      ].each do |name|
        expect(canonical_names).not_to include(name)
      end
    end

    it 'stays unique' do
      canonical_names = described_class::EXERCISES.map { |attrs| attrs[:name] }

      expect(canonical_names).to match_array(canonical_names.uniq)
    end
  end
end
