class SettingsController < ApplicationController
  before_action :set_user

  def show
  end

  def update
    if @user.update(user_params)
      redirect_to settings_path, notice: 'Settings updated successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    unless @user.authenticate(params[:current_password])
      @user.errors.add(:current_password, 'is incorrect')
      render :show, status: :unprocessable_entity
      return
    end

    if params[:password].blank?
      @user.errors.add(:password, "can't be blank")
      render :show, status: :unprocessable_entity
      return
    end

    if @user.update(password_params)
      redirect_to settings_path, notice: 'Password changed successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = Current.user
  end

  def user_params
    params.require(:user).permit(:name, :email_address, :preferred_unit, :default_rest_seconds)
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
