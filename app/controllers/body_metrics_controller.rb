# frozen_string_literal: true

# Manages bodyweight and body measurement tracking
# Allows users to log weigh-ins and measurements (chest, waist, arms, legs)
class BodyMetricsController < ApplicationController
  before_action :set_body_metric, only: [ :edit, :update, :destroy ]

  # GET /body_metrics
  # Shows weight trend, measurements timeline, and Wilks score
  def index
    @body_metrics = Current.user.body_metrics.ordered.limit(100)
    @recent_weight_entries = Current.user.body_metrics.with_weight.ordered.limit(30)
    @measurement_entries = Current.user.body_metrics.with_measurements.ordered.limit(10)

    # Weight trend data for chart (last 90 days)
    @weight_trend_data = Current.user.body_metrics
      .with_weight
      .where('measured_at >= ?', 90.days.ago)
      .order(:measured_at)
      .pluck(:measured_at, :weight_kg)
      .map { |date, weight| [ date.to_date.to_s, weight ] }

    # Calculate current Wilks score if we have recent weight
    @current_weight_kg = Current.user.body_metrics.current_weight_kg
    if @current_weight_kg
      # Get user's best lifts for Wilks calculation
      @best_squat_kg = best_lift_for_exercise('Squat')
      @best_bench_kg = best_lift_for_exercise('Bench Press')
      @best_deadlift_kg = best_lift_for_exercise('Deadlift')

      total_kg = [ @best_squat_kg, @best_bench_kg, @best_deadlift_kg ].compact.sum
      if total_kg > 0
        calculator = WilksCalculator.new(
          bodyweight_kg: @current_weight_kg,
          total_kg: total_kg,
          sex: :male # TODO: Add sex to user profile
        )
        @wilks_score = calculator.calculate
      end
    end

    # Bodyweight-relative strength for common lifts
    @relative_strength = {}
    if @current_weight_kg&.> 0
      %w[Squat Bench\ Press Deadlift Overhead\ Press].each do |exercise_name|
        best_kg = best_lift_for_exercise(exercise_name)
        @relative_strength[exercise_name] = (best_kg / @current_weight_kg).round(2) if best_kg
      end
    end
  end

  # GET /body_metrics/new
  # Form for logging new weight/measurements
  def new
    @body_metric = Current.user.body_metrics.build(measured_at: Time.current)

    # Pre-fill with last known measurements (makes logging weight-only entries fast)
    last_entry = Current.user.body_metrics.with_measurements.ordered.first
    if last_entry
 @body_metric.chest_cm = last_entry.chest_cm
      @body_metric.waist_cm = last_entry.waist_cm
      @body_metric.hips_cm = last_entry.hips_cm
      @body_metric.left_arm_cm = last_entry.left_arm_cm
      @body_metric.right_arm_cm = last_entry.right_arm_cm
      @body_metric.left_leg_cm = last_entry.left_leg_cm
      @body_metric.right_leg_cm = last_entry.right_leg_cm
    end
  end

  # POST /body_metrics
  def create
    @body_metric = Current.user.body_metrics.build(body_metric_params)

    # Convert weight from user's preferred unit to kg
    if params[:body_metric][:weight_display].present?
      weight_input = params[:body_metric][:weight_display].to_f
      @body_metric.weight_kg = if Current.user.preferred_unit == 'lbs'
        weight_input / 2.20462
      else
        weight_input
      end
    end

    if @body_metric.save
      redirect_to body_metrics_path, notice: 'Body metrics logged successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /body_metrics/:id/edit
  def edit
    # Pre-fill weight_display for form
    @weight_display = WeightConverter.kg_to_user_unit(@body_metric.weight_kg, Current.user) if @body_metric.weight_kg
  end

  # PATCH /body_metrics/:id
  def update
    # Convert weight from user's preferred unit to kg
    if params[:body_metric][:weight_display].present?
      weight_input = params[:body_metric][:weight_display].to_f
      @body_metric.weight_kg = if Current.user.preferred_unit == 'lbs'
        weight_input / 2.20462
      else
        weight_input
      end
    end

    if @body_metric.update(body_metric_params.except(:weight_kg))
      redirect_to body_metrics_path, notice: 'Body metrics updated successfully.'
    else
      @weight_display = WeightConverter.kg_to_user_unit(@body_metric.weight_kg, Current.user) if @body_metric.weight_kg
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /body_metrics/:id
  def destroy
    @body_metric.destroy
    redirect_to body_metrics_path, notice: 'Body metrics entry deleted.'
  end

  private

  def set_body_metric
    @body_metric = Current.user.body_metrics.find(params[:id])
  end

  def body_metric_params
    params.require(:body_metric).permit(
      :measured_at, :weight_kg, :chest_cm, :waist_cm, :hips_cm,
      :left_arm_cm, :right_arm_cm, :left_leg_cm, :right_leg_cm, :notes
    )
  end

  # Find the best (heaviest) lift for an exercise
  def best_lift_for_exercise(exercise_name)
    exercise = Exercise.find_by(name: exercise_name, user_id: nil) # Global exercise
    return nil unless exercise

    Current.user.workouts
      .joins(workout_exercises: { exercise_sets: :workout_exercise })
      .where(workout_exercises: { exercise_id: exercise.id })
      .where(exercise_sets: { is_warmup: false })
      .maximum('exercise_sets.weight_kg')
  end
end
