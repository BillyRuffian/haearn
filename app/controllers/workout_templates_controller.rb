class WorkoutTemplatesController < ApplicationController
  before_action :set_template, only: [ :show, :edit, :update, :destroy, :start_workout, :reorder_blocks, :toggle_pin ]

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

  # POST /workout_templates/:id/toggle_pin
  # Pin or unpin a template for quick dashboard access
  def toggle_pin
    @template.toggle_pin!
    status = @template.pinned? ? 'pinned' : 'unpinned'

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(dom_id(@template, :pin),
          partial: 'workout_templates/pin_button',
          locals: { template: @template })
      end
      format.html do
        if turbo_frame_request?
          render partial: 'workout_templates/pin_button', locals: { template: @template }
        else
          redirect_back fallback_location: @template, notice: "Template #{status}."
        end
      end
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
    source_workout = Current.user.workouts
      .includes(workout_blocks: { workout_exercises: [ :exercise, :machine, :exercise_sets ] })
      .find(params[:workout_id])

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
        set_targets = template_set_targets(we)

        template_block.template_exercises.build(
          exercise: we.exercise,
          machine: we.machine,
          persistent_notes: we.persistent_notes,
          target_sets: set_targets[:target_sets],
          target_reps: set_targets[:target_reps],
          target_weight_kg: set_targets[:target_weight_kg]
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

  def template_set_targets(workout_exercise)
    working_sets = workout_exercise.exercise_sets.select { |set| set.is_warmup == false }
    {
      target_sets: working_sets.size,
      target_reps: averaged_value(working_sets.filter_map(&:reps), scale: 0)&.to_i,
      target_weight_kg: averaged_value(working_sets.filter_map(&:weight_kg), scale: 2)
    }
  end

  def averaged_value(values, scale:)
    return nil if values.empty?

    total = values.reduce(BigDecimal('0')) { |sum, value| sum + BigDecimal(value.to_s) }
    average = total / BigDecimal(values.size.to_s)
    average.round(scale)
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
