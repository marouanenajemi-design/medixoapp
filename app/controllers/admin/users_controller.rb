class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :destroy, :toggle_super_admin]

  def index
    @users = User.includes(:clinic).order(created_at: :desc)
  end

  def show
    @clinic = @user.clinic
  end

  def toggle_super_admin
    if @user == current_user
      redirect_to admin_user_path(@user), alert: t("admin.users.cannot_change_own_role")
      return
    end

    @user.update!(super_admin: !@user.super_admin?)
    redirect_to admin_users_path, notice: t("admin.users.role_updated", email: @user.email)
  end

  def destroy
    if @user == current_user
      redirect_to admin_users_path, alert: t("admin.users.cannot_delete_self")
      return
    end

    @user.destroy
    redirect_to admin_users_path, notice: t("admin.users.deleted", email: @user.email)
  end

  private

  def set_user
    @user = User.find(params[:id])
  end
end
