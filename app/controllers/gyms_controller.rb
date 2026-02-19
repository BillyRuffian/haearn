# Manages user's gym locations and their associated equipment
# Each gym can have multiple machines with specific configurations
class GymsController < ApplicationController
  before_action :set_gym, only: %i[show edit update destroy set_default]

  # GET /gyms
  # Lists all user's gyms with their machines
  def index
    @gyms = Current.user.gyms.ordered.includes(:machines)
    @gym = Gym.new # For the inline new form
  end

  def show
    @machines = @gym.machines.ordered
    @new_machine = @gym.machines.build(display_unit: Current.user.preferred_unit)

    # If this is a Turbo Frame request for the gym card, return just the partial
    if turbo_frame_request_id == "gym_#{@gym.id}"
      render partial: 'gyms/gym', locals: { gym: @gym }
    end
  end

  def new
    @gym = Current.user.gyms.build
  end

  # POST /gyms
  # Creates new gym location
  # Supports return_to for redirecting back to workout creation flow
  def create
    @gym = Current.user.gyms.build(gym_params)

    respond_to do |format|
      if @gym.save
        # Handle both Turbo Frame inline creation and full page flow
        format.turbo_stream {
          if turbo_frame_request?
            render turbo_stream: turbo_stream.prepend('gyms', partial: 'gyms/gym', locals: { gym: @gym }) + turbo_stream.update('new_gym_form', partial: 'gyms/form', locals: { gym: Gym.new })
          else
            redirect_to safe_return_to(params[:return_to]) || new_workout_path, notice: 'Gym created! Now start your workout.'
          end
        }
        format.html { redirect_to safe_return_to(params[:return_to]) || gyms_path, notice: 'Gym created successfully.' }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.update('new_gym_form', partial: 'gyms/form', locals: { gym: @gym }) }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @gym.update(gym_params)
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@gym, partial: 'gyms/gym', locals: { gym: @gym }) }
        format.html { redirect_to gyms_path, notice: 'Gym updated successfully.' }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@gym, partial: 'gyms/form', locals: { gym: @gym }) }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @gym.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@gym) }
      format.html { redirect_to gyms_path, notice: 'Gym deleted.' }
    end
  end

  # PATCH /gyms/:id/set_default
  # Sets this gym as the user's default for new workouts
  def set_default
    Current.user.update!(default_gym: @gym)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          'gym-header',
          partial: 'gyms/header',
          locals: { gym: @gym }
        )
      }
      format.html { redirect_to @gym, notice: "#{@gym.name} is now your default gym." }
    end
  end

  private

  def set_gym
    @gym = Current.user.gyms.find(params[:id])
  end

  def gym_params
    params.require(:gym).permit(:name, :location, :notes)
  end
end
