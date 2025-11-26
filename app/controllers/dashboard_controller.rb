class DashboardController < ApplicationController
  def show
    @knowledge_advice = Knowledge.active.order(created_at: :desc).first
  end
end
