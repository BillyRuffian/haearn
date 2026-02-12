module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :edit, :update, :toggle_admin, :deactivate, :reactivate, :impersonate ]

    PER_PAGE = 25

    def index
      authorize User
      scope = policy_scope(User)

      scope = scope.where('name LIKE ? OR email_address LIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

      case params[:status]
      when 'active'
        scope = scope.active
      when 'deactivated'
        scope = scope.deactivated
      end

      scope = scope.admins if params[:role] == 'admin'

      @page = [ params.fetch(:page, 1).to_i, 1 ].max
      @total_count = scope.count
      @users = scope.order(created_at: :desc).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
      @total_pages = (@total_count / PER_PAGE.to_f).ceil
    end

    def show
      authorize @user
      @workout_count = @user.workouts.count
      @set_count = @user.exercise_sets.count
      @last_workout = @user.workouts.order(created_at: :desc).first
    end

    def edit
      authorize @user
    end

    def update
      authorize @user
      if @user.update(user_params)
        log_admin_action(action: 'update_user', target_user: @user)
        redirect_to admin_user_path(@user), notice: 'User updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle_admin
      authorize @user
      @user.update!(admin: !@user.admin?)
      action = @user.admin? ? 'promote_to_admin' : 'demote_from_admin'
      log_admin_action(action: action, target_user: @user)
      redirect_to admin_user_path(@user), notice: "#{@user.name} is #{@user.admin? ? 'now' : 'no longer'} an admin."
    end

    def deactivate
      authorize @user
      @user.update!(deactivated_at: Time.current)
      @user.sessions.destroy_all
      log_admin_action(action: 'deactivate_user', target_user: @user)
      redirect_to admin_user_path(@user), notice: "#{@user.name} has been deactivated."
    end

    def reactivate
      authorize @user
      @user.update!(deactivated_at: nil)
      log_admin_action(action: 'reactivate_user', target_user: @user)
      redirect_to admin_user_path(@user), notice: "#{@user.name} has been reactivated."
    end

    def impersonate
      authorize @user
      session[:admin_session_id] = Current.session.id
      log_admin_action(action: 'impersonate_user', target_user: @user)
      start_new_session_for(@user)
      redirect_to root_path, notice: "You are now impersonating #{@user.name}."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :email_address)
    end
  end
end
