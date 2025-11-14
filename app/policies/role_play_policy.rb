# frozen_string_literal: true

class RolePlayPolicy < ApplicationPolicy
  # Allow all authenticated users to view role plays
  def index?
    true
  end

  def show?
    true
  end

  # Only admins can create, update, or destroy
  def create?
    account_user.admin?
  end

  def update?
    account_user.admin?
  end

  def destroy?
    account_user.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # All authenticated users can see all role plays
      scope.all
    end
  end
end
