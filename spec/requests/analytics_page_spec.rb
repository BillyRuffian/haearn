require 'rails_helper'

RSpec.describe 'Analytics page', type: :request do
  def build_user(email:, preferred_unit: 'kg')
    User.create!(
      email_address: email,
      password: 'password',
      password_confirmation: 'password',
      name: 'Analytics Request User',
      preferred_unit: preferred_unit
    )
  end

  it 'renders stable section navigation and useful empty states for a new user' do
    user = build_user(email: 'analytics-page-empty@example.com')
    sign_in_as(user)

    get analytics_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)

    expect(document.at_css('h1').text).to include('Analytics')
    expect(response.body).to include('Load volume means external weight × reps from working sets')

    %w[training-load progress strength-profile muscle-training history-signals].each do |section_id|
      expect(document.css("##{section_id}").length).to eq(1)
      expect(document.at_css(".analytics-nav a[href='##{section_id}']")).to be_present
    end

    expect(response.body).to include('No completed workout yet')
    expect(response.body).to include('Complete weighted working sets to see rep-range and progress analysis.')
    expect(response.body).to include('Complete weighted working sets on exercises with a primary muscle')
    expect(response.body).to include('Record at least one set for an exercise')
    expect(response.body).to include('kg·reps')
  end

  it 'renders responsive, accessible chart hooks and exact-context controls with recent training data' do
    user = build_user(email: 'analytics-page-data@example.com')
    gym = user.gyms.create!(name: 'Request Gym')
    machine = gym.machines.create!(name: 'Cable Stack', equipment_type: 'machine', display_unit: 'kg')
    exercise = user.exercises.create!(
      name: 'Request Press',
      exercise_type: 'reps',
      has_weight: true,
      primary_muscle_group: 'chest'
    )
    workout = user.workouts.create!(gym: gym, started_at: 2.days.ago, finished_at: 2.days.ago + 1.hour)
    block = workout.workout_blocks.create!(position: 1, rest_seconds: 90)
    workout_exercise = block.workout_exercises.create!(exercise: exercise, machine: machine, position: 1)

    [ 3, 8, 12, 20 ].each_with_index do |reps, index|
      workout_exercise.exercise_sets.create!(
        position: index + 1,
        reps: reps,
        weight_kg: 40 + index,
        is_warmup: false,
        completed_at: workout.started_at + (index + 1).minutes
      )
    end

    sign_in_as(user)
    get analytics_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    canvases = document.css('canvas')

    expect(canvases).not_to be_empty
    canvases.each do |canvas|
      expect(canvas.text.strip).not_to be_empty
      expect(canvas.ancestors('.analytics-chart')).not_to be_empty
      expect(canvas.parent['role']).to eq('img')
      expect(canvas.parent['aria-label']).to be_present
    end

    expect(document.at_css("[data-controller='strength-curve'] select[data-action='change->strength-curve#changeContext']")).to be_present
    expect(document.at_css("[data-controller='muscle-group-chart'] select[data-action='change->muscle-group-chart#changePeriod']")).to be_present
    expect(document.css("[data-chart-type-value='radar']")).to be_empty
    expect(response.body).to include('Request Press — Cable Stack')
    expect(response.body).to include('Heavier sets and best single-set load')
    expect(response.body).to include('Each marker has equal visual weight')
  end
end
