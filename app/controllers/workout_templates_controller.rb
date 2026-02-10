class WorkoutTemplatesController < ApplicationController
  before_action :set_template, only: [ :show, :edit, :update, :destroy, :start_workout, :reorder_blocks ]

  # GET /workout_templates
  def index
    @templates = Current.user.workout_templates.includes(
      template_blocks: { template_exercises: [ :exercise, :machine ] }
    ).recent
  end

  # GET /workout_templates/:id
  def show
    @template_blocks = @template.template_blocks.includes(
      template_exercises: [ :exercise, :machine ]
    ).ordered
  end

  # GET /workout_templates/new
  def new
    @template = Current.user.workout_templates.build
    @gyms = Current.user.gyms.ordered
  end

  # POST /workout_templates
  def create
    @template = Current.user.workout_templates.build(template_params)

    if @template.save
      redirect_to @template, notice: 'Template created successfully.'
    else
      @gyms = Current.user.gyms.ordered
      render :new, status: :unprocessable_entity
    end
  end

  # GET /workout_templates/:id/edit
  def edit
    @gyms = Current.user.gyms.ordered
  end

  # PATCH /workout_templates/:id
  def update
    if @template.update(template_params)
      redirect_to @template, notice: 'Template updated successfully.'
    else
      @gyms = Current.user.gyms.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /workout_templates/:id
  def destroy
    @template.destroy
    redirect_to workout_templates_path, notice: 'Template deleted successfully.'
  end

  # POST /workout_templates/:id/start_workout
  # Creates a new workout from this template
  def start_workout
    workout = create_workout_from_template(@template)

    if workout.persisted?
      redirect_to workout, notice: "Started workout from template \"#{@template.name}\"."
    else
      redirect_to @template, alert: "Failed to start workout: #{workout.errors.full_messages.join(', ')}"
    end
  end

  # PATCH /workout_templates/:id/reorder_blocks
  # Updates block positions for drag-and-drop reordering
  def reorder_blocks
    block_ids = params[:block_ids]

    return head :bad_request unless block_ids.is_a?(Array)

    ActiveRecord::Base.transaction do
      block_ids.each_with_index do |block_id, index|
        block = @template.template_blocks.find(block_id)
        block.update!(position: index + 1)
      end
    end

    head :ok
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  # POST /workouts/:workout_id/save_as_template
  # Creates a template from an existing workout
  def create_from_workout
    source_workout = Current.user.workouts.find(params[:workout_id])

    template = WorkoutTemplate.new(
      user: Current.user,
      name: params[:name] || "#{source_workout.gym&.name || 'Workout'} - #{source_workout.started_at.strftime('%b %d')}",
      description: params[:description]
    )

    # Copy workout structure to template
    source_workout.workout_blocks.ordered.each do |block|
      template_block = template.template_blocks.build(
        position: block.position,
        rest_seconds: block.rest_seconds
      )

      block.workout_exercises.each do |we|
        # Calculate average/target values from completed sets
        working_sets = we.exercise_sets.where(is_warmup: false)
        avg_weight = working_sets.average(:weight_kg)&.round(2)
        avg_reps = working_sets.average(:reps)&.round

        template_block.template_exercises.build(
          exercise: we.exercise,
          machine: we.machine,
          persistent_notes: we.persistent_notes,
          target_sets: working_sets.count,
          target_reps: avg_reps,
          target_weight_kg: avg_weight
        )
      end
    end

    if template.save
      redirect_to template, notice: "Template \"#{template.name}\" created successfully."
    else
      redirect_to source_workout, alert: "Failed to create template: #{template.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_template
    @template = Current.user.workout_templates.find(params[:id])
  end

  def template_params
    params.require(:workout_template).permit(:name, :description)
  end

  # Creates a new workout instance from a template
  def create_workout_from_template(template)
    workout = Current.user.workouts.build(
      gym_id: Current.user.default_gym_id,
      started_at: Time.current
    )

    template.template_blocks.ordered.each do |template_block|
      workout_block = workout.workout_blocks.build(
        position: template_block.position,
        rest_seconds: template_block.rest_seconds
      )

      template_block.template_exercises.each do |template_exercise|
        workout_block.workout_exercises.build(
          exercise: template_exercise.exercise,
          machine: template_exercise.machine,
          persistent_notes: template_exercise.persistent_notes
        )
      end
    end

    workout.save
    workout
  end
end
