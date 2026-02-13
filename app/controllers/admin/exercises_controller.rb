module Admin
  class ExercisesController < BaseController
    before_action :set_exercise, only: [ :show, :edit, :update, :destroy, :promote, :merge, :perform_merge ]

    PER_PAGE = 25

    def index
      authorize Exercise
      scope = policy_scope(Exercise)

      scope = scope.where('name LIKE ?', "%#{params[:search]}%") if params[:search].present?

      case params[:scope_filter]
      when 'global'
        scope = scope.global
      when 'user_created'
        scope = scope.where.not(user_id: nil)
      end

      @page = [ params.fetch(:page, 1).to_i, 1 ].max
      @total_count = scope.count
      @exercises = scope.order(:name).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
      @total_pages = (@total_count / PER_PAGE.to_f).ceil
    end

    def show
      authorize @exercise
      @usage_count = @exercise.workout_exercises.count
      @user_count = @exercise.workout_exercises
        .joins(workout_block: :workout)
        .select('workouts.user_id')
        .distinct
        .count
    end

    def new
      @exercise = Exercise.new
      authorize @exercise
    end

    def create
      @exercise = Exercise.new(exercise_params)
      @exercise.user_id = nil
      authorize @exercise

      if @exercise.save
        log_admin_action(action: 'create_global_exercise', resource: @exercise)
        redirect_to admin_exercise_path(@exercise), notice: 'Global exercise created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @exercise
    end

    def update
      authorize @exercise
      if @exercise.update(exercise_params)
        log_admin_action(action: 'update_exercise', resource: @exercise)
        redirect_to admin_exercise_path(@exercise), notice: 'Exercise updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @exercise
      if @exercise.destroy
        log_admin_action(action: 'delete_exercise', resource: @exercise)
        redirect_to admin_exercises_path, notice: 'Exercise deleted.'
      else
        redirect_to admin_exercise_path(@exercise), alert: 'Cannot delete exercise: it is in use.'
      end
    end

    def promote
      authorize @exercise
      original_user = @exercise.user
      @exercise.update!(user_id: nil)
      log_admin_action(
        action: 'promote_exercise',
        target_user: original_user,
        resource: @exercise,
        metadata: { original_user_id: original_user&.id }
      )
      redirect_to admin_exercise_path(@exercise), notice: "#{@exercise.name} promoted to global exercise."
    end

    def review
      authorize Exercise, :review?
      @exercises = Exercise.where.not(user_id: nil)
        .left_joins(:workout_exercises)
        .group('exercises.id')
        .order('COUNT(workout_exercises.id) DESC')
        .limit(50)
        .select('exercises.*, COUNT(workout_exercises.id) AS usage_count')
    end

    def merge
      authorize @exercise
      @target_exercises = Exercise.where.not(id: @exercise.id).order(:name)
      @target_exercises = @target_exercises.where('name LIKE ?', "%#{params[:search]}%") if params[:search].present?
      @usage_count = @exercise.workout_exercises.count
      @template_count = TemplateExercise.where(exercise_id: @exercise.id).count
    end

    def perform_merge
      authorize @exercise
      target = Exercise.find(params[:target_id])

      result = ExerciseMerger.call(target: target, duplicate: @exercise)

      if result.success?
        log_admin_action(
          action: 'merge_exercise',
          resource: target,
          metadata: {
            merged_exercise_id: @exercise.id,
            merged_exercise_name: @exercise.name,
            message: result.message
          }
        )
        redirect_to admin_exercise_path(target), notice: result.message
      else
        redirect_to merge_admin_exercise_path(@exercise), alert: result.message
      end
    end

    private

    def set_exercise
      @exercise = Exercise.find(params[:id])
    end

    def exercise_params
      params.require(:exercise).permit(:name, :exercise_type, :has_weight, :description, :primary_muscle_group)
    end
  end
end
