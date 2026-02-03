class GymsController < ApplicationController
  before_action :set_gym, only: %i[show edit update destroy]

  def index
    @gyms = Current.user.gyms.ordered.includes(:machines)
    @gym = Gym.new # For the inline new form
  end

  def show
    @machines = @gym.machines.ordered
  end

  def new
    @gym = Current.user.gyms.build
  end

  def create
    @gym = Current.user.gyms.build(gym_params)

    respond_to do |format|
      if @gym.save
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("gyms", partial: "gyms/gym", locals: { gym: @gym }) + turbo_stream.update("new_gym_form", partial: "gyms/form", locals: { gym: Gym.new }) }
        format.html { redirect_to gyms_path, notice: "Gym created successfully." }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.update("new_gym_form", partial: "gyms/form", locals: { gym: @gym }) }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @gym.update(gym_params)
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@gym, partial: "gyms/gym", locals: { gym: @gym }) }
        format.html { redirect_to gyms_path, notice: "Gym updated successfully." }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@gym, partial: "gyms/form", locals: { gym: @gym }) }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @gym.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@gym) }
      format.html { redirect_to gyms_path, notice: "Gym deleted." }
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
