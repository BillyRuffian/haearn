require 'rails_helper'

RSpec.describe WeeklySummaryMailer, type: :mailer do
  let(:user) { users(:one) }
  let(:summary) do
    {
      week_label: 'Aug 17 - Aug 23, 2026',
      this_week: {
        workout_count: 3,
        total_volume_kg: 3_000,
        total_sets: 12,
        total_reps: 96,
        total_duration_minutes: 150,
        unique_exercises: 6
      },
      vs_average: {
        baseline_weeks: 2,
        avg_workout_count: 1.5,
        avg_volume_kg: 2_000,
        avg_sets: 8.0,
        avg_duration_minutes: 100.0,
        workout_count_pct: 100,
        volume_pct: 50,
        sets_pct: 50,
        duration_pct: 50
      },
      highlights: [ { type: :volume_spike, message: 'Moved 50% more volume than average.' } ],
      new_prs: [],
      top_exercises: [ { exercise_name: 'Deadlift', volume_kg: 1_500, set_count: 4 } ],
      consistency: { weeks_trained_last_4: 3, current_streak: 2 }
    }
  end

  before do
    calculator = instance_double(WeeklySummaryCalculator, calculate: summary)
    allow(WeeklySummaryCalculator).to receive(:new).and_return(calculator)
  end

  it 'renders one responsive email document with a desktop grid that stacks on phones' do
    html = described_class.weekly_report(user:, week_start: Time.zone.local(2026, 8, 17)).html_part.body.decoded

    expect(html.scan(/<!DOCTYPE html>/i).length).to eq(1)
    expect(html.scan(/<html(?:\s|>)/i).length).to eq(1)
    expect(html).to include('name="viewport"')
    expect(html).to include('@media only screen and (max-width: 600px)')
    expect(html).to include('class="metric-cell" width="50%"')
    expect(html).to include('display: block !important;')
    expect(html).to include('max-width: 680px')
  end

  it 'makes the comparison period, percentages, and averages explicit in both parts' do
    mail = described_class.weekly_report(user:, week_start: Time.zone.local(2026, 8, 17))
    html = mail.html_part.body.decoded
    text = mail.text_part.body.decoded

    expect(html).to include('previous 2 calendar weeks of available history')
    expect(html).to include('+50% vs 2 weeks avg')
    expect(html).to include('Average 2,000 kg')
    expect(html).to include('Training time')

    expect(text).to include('previous 2 calendar weeks of available history')
    expect(text).to include('+50% vs 2 weeks avg')
    expect(text).to include('Average: 2,000 kg')
    expect(text).to include('Training time: 2.5 hr')
  end

  it 'labels a zero historical metric as unavailable instead of reporting zero percent' do
    summary[:vs_average][:volume_pct] = nil

    mail = described_class.weekly_report(user:, week_start: Time.zone.local(2026, 8, 17))

    expect(mail.html_part.body.decoded).to include('No prior baseline')
    expect(mail.text_part.body.decoded).to include('No prior baseline')
  end
end
