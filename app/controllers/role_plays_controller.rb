class RolePlaysController < ApplicationController
  before_action :authenticate_user!

  def index
    @role_plays = RolePlay.active.all
  end

  def show
    @role_play = RolePlay.find(params[:id])
  end
end
