# frozen_string_literal: true

# Controller for managing exercises within workout templates
class TemplateExercisesController < ApplicationController
  before_action :set_template
  before_action :set_template_exercise, only: [ :edit, :update, :destroy ]

  # GET /workout_templates/:workout_template_id/exercises/new
  # Shows exercise picker modal
  def new
    @template_blocks = @template.template_blocks.ordered
    @template_exercise = TemplateExercise.new
    @exercises = Exercise.for_user(Current.user).ordered
    @machines = Machine.where(gym_id: Current.user.gym_ids).ordered
  end

  # POST /workout_templates/:workout_template_id/exercises
  # Adds an exercise to the template
  def create
    # Use selected block or create a new one
    if template_exercise_params[:block_id].present?
      @template_block = @template.template_blocks.find(template_exercise_params[:block_id])
    else
      @template_block = @template.template_blocks.build(
        position: next_block_position,
        rest_seconds: 90
      )
      @template_block.save!
    end

    @template_exercise = @template_block.template_exercises.build(
      exercise_id: template_exercise_params[:exercise_id],
      machine_id: template_exercise_params[:machine_id],
      target_sets: template_exercise_params[:target_sets],
      target_reps: template_exercise_params[:target_reps],
      target_weight_kg: template_exercise_params[:target_weight_kg],
      persistent_notes: template_exercise_params[:persistent_notes]
    )

    if @template_exercise.save
      redirect_to @template, notice: 'Exercise added to template.'
    else
      @template_blocks = @template.template_blocks.ordered
      @exercises = Exercise.for_user(Current.user).ordered
      @machines = Machine.where(gym_id: Current.user.gym_ids).ordered
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid
    @template_blocks = @template.template_blocks.ordered
    @exercises = Exercise.for_user(Current.user).ordered
    @machines = Machine.where(gym_id: Current.user.gym_ids).ordered
    @template_exercise ||= TemplateExercise.new
    render :new, status: :unprocessable_entity
  end

  # GET /workout_templates/:workout_template_id/exercises/:id/edit
  # Shows form to edit exercise details
  def edit
    @exercises = Exercise.for_user(Current.user).ordered
    @machines = Machine.where(gym_id: Current.user.gym_ids).ordered
  end

  # PATCH /workout_templates/:workout_template_id/exercises/:id
  def update
    if @template_exercise.update(template_exercise_params.except(:block_position))
      redirect_to @template, notice: 'Exercise updated.'
    else
      @exercises = Exercise.for_user(Current.user).ordered
      @machines = Machine.where(gym_id: Current.user.gym_ids).ordered
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /workout_templates/:workout_template_id/exercises/:id
  def destroy
    @template_exercise.destroy
    redirect_to @template, notice: 'Exercise removed from template.'
  end

  private

  def set_template
    @template = Current.user.workout_templates.find(params[:workout_template_id])
  end

  def set_template_exercise
    @template_exercise = @template.template_exercises.find(params[:id])
  end

  def template_exercise_params
    params.require(:template_exercise).permit(
      :exercise_id,
      :machine_id,
      :target_sets,
      :target_reps,
      :target_weight_kg,
      :persistent_notes,
      :block_id
    )
  end

  def next_block_position
    @template.template_blocks.maximum(:position).to_i + 1
  end
end
