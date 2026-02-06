# Manages gym equipment/machines with support for photos, weight ratios, and display units
# Weight ratios handle pulley systems (e.g., 2:1 cables where you lift half the selected weight)
# Display units allow tracking what the machine shows vs what weight is actually lifted
class MachinesController < ApplicationController
  before_action :set_gym
  before_action :set_machine, only: %i[show edit update destroy delete_photo]

  # Redirects to gym show page (machines are displayed there)
  def index
    redirect_to gym_path(@gym)
  end

  def show
    redirect_to gym_path(@gym)
  end

  def new
    @machine = @gym.machines.build
    @return_to = params[:return_to]
  end

  # POST /gyms/:gym_id/machines
  # Creates new equipment/machine for the gym
  # Supports return_to for workout setup flow (create machine, then select it)
  def create
    @machine = @gym.machines.build(machine_params)

    respond_to do |format|
      if @machine.save
        # Support for workout flow: create machine, then return to machine picker
        if params[:return_to].present?
          safe_url = safe_return_to(params[:return_to], fallback: gym_path(@gym))
          format.html { redirect_to safe_url, notice: 'Equipment added! Now select it.' }
          format.turbo_stream { redirect_to safe_url, notice: 'Equipment added! Now select it.' }
        else
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend('machines', partial: 'machines/machine', locals: { machine: @machine, gym: @gym }),
              turbo_stream.update('new_machine_form', partial: 'machines/form', locals: { machine: @gym.machines.build, gym: @gym })
            ]
          end
          format.html { redirect_to gym_path(@gym), notice: 'Equipment added successfully.' }
        end
      else
        @return_to = params[:return_to]
        format.turbo_stream { render turbo_stream: turbo_stream.update('new_machine_form', partial: 'machines/form', locals: { machine: @machine, gym: @gym }) }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @machine.update(machine_params)
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@machine, partial: 'machines/machine', locals: { machine: @machine, gym: @gym }) }
        format.html { redirect_to gym_path(@gym), notice: 'Equipment updated successfully.' }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@machine, partial: 'machines/edit_form', locals: { machine: @machine, gym: @gym }) }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @machine.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@machine) }
      format.html { redirect_to gym_path(@gym), notice: 'Equipment deleted.' }
    end
  end

  # DELETE /gyms/:gym_id/machines/:id/delete_photo?photo_id=X
  # Removes a specific photo attachment from the machine
  def delete_photo
    photo = @machine.photos.find(params[:photo_id])
    photo.purge

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("photo_#{params[:photo_id]}") }
      format.html { redirect_to edit_gym_machine_path(@gym, @machine), notice: 'Photo deleted.' }
    end
  end

  private

  def set_gym
    @gym = Current.user.gyms.find(params[:gym_id])
  end

  def set_machine
    @machine = @gym.machines.find(params[:id])
  end

  # Strong params including equipment type, weight calculations, and photos
  # weight_ratio: for pulley systems (0.5 = 2:1 ratio, you lift half)
  # display_unit: what unit the machine displays (kg/lbs)
  def machine_params
    params.require(:machine).permit(:name, :equipment_type, :weight_ratio, :display_unit, :notes, photos: [])
  end
end
