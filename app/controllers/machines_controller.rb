class MachinesController < ApplicationController
  before_action :set_gym
  before_action :set_machine, only: %i[show edit update destroy]

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

  def create
    @machine = @gym.machines.build(machine_params)

    respond_to do |format|
      if @machine.save
        # If we have a return_to URL, redirect there instead
        if params[:return_to].present?
          format.html { redirect_to params[:return_to], notice: "Machine added! Now select it." }
          format.turbo_stream { redirect_to params[:return_to], notice: "Machine added! Now select it." }
        else
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend("machines", partial: "machines/machine", locals: { machine: @machine, gym: @gym }),
              turbo_stream.update("new_machine_form", partial: "machines/form", locals: { machine: @gym.machines.build, gym: @gym })
            ]
          end
          format.html { redirect_to gym_path(@gym), notice: "Machine added successfully." }
        end
      else
        @return_to = params[:return_to]
        format.turbo_stream { render turbo_stream: turbo_stream.update("new_machine_form", partial: "machines/form", locals: { machine: @machine, gym: @gym }) }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @machine.update(machine_params)
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@machine, partial: "machines/machine", locals: { machine: @machine, gym: @gym }) }
        format.html { redirect_to gym_path(@gym), notice: "Machine updated successfully." }
      else
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@machine, partial: "machines/edit_form", locals: { machine: @machine, gym: @gym }) }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @machine.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@machine) }
      format.html { redirect_to gym_path(@gym), notice: "Machine deleted." }
    end
  end

  private

  def set_gym
    @gym = Current.user.gyms.find(params[:gym_id])
  end

  def set_machine
    @machine = @gym.machines.find(params[:id])
  end

  def machine_params
    params.require(:machine).permit(:name, :equipment_type, :weight_ratio, :display_unit, :notes)
  end
end
