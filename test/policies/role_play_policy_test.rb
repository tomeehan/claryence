require "test_helper"

class RolePlayPolicyTest < ActiveSupport::TestCase
  def setup
    @role_play = role_plays(:one)
    @admin_account_user = account_users(:company_admin) # Has admin: true in roles
    @regular_account_user = account_users(:company_regular_user) # No admin role
  end

  # Index Policy Tests
  test "index? allows all authenticated users" do
    policy = RolePlayPolicy.new(@regular_account_user, RolePlay)
    assert policy.index?, "Regular users should be able to view index"

    policy = RolePlayPolicy.new(@admin_account_user, RolePlay)
    assert policy.index?, "Admins should be able to view index"
  end

  # Show Policy Tests
  test "show? allows all authenticated users" do
    policy = RolePlayPolicy.new(@regular_account_user, @role_play)
    assert policy.show?, "Regular users should be able to view role plays"

    policy = RolePlayPolicy.new(@admin_account_user, @role_play)
    assert policy.show?, "Admins should be able to view role plays"
  end

  # Create Policy Tests
  test "create? only allows admins" do
    policy = RolePlayPolicy.new(@regular_account_user, RolePlay.new)
    assert_not policy.create?, "Regular users should not be able to create role plays"

    policy = RolePlayPolicy.new(@admin_account_user, RolePlay.new)
    assert policy.create?, "Admins should be able to create role plays"
  end

  # Update Policy Tests
  test "update? only allows admins" do
    policy = RolePlayPolicy.new(@regular_account_user, @role_play)
    assert_not policy.update?, "Regular users should not be able to update role plays"

    policy = RolePlayPolicy.new(@admin_account_user, @role_play)
    assert policy.update?, "Admins should be able to update role plays"
  end

  # Destroy Policy Tests
  test "destroy? only allows admins" do
    policy = RolePlayPolicy.new(@regular_account_user, @role_play)
    assert_not policy.destroy?, "Regular users should not be able to destroy role plays"

    policy = RolePlayPolicy.new(@admin_account_user, @role_play)
    assert policy.destroy?, "Admins should be able to destroy role plays"
  end

  # Scope Tests
  test "scope resolves to all role plays for authenticated users" do
    scope = Pundit.policy_scope!(@regular_account_user, RolePlay)
    assert_equal RolePlay.count, scope.count, "Regular users should see all role plays"

    scope = Pundit.policy_scope!(@admin_account_user, RolePlay)
    assert_equal RolePlay.count, scope.count, "Admins should see all role plays"
  end

  test "scope includes both active and inactive role plays" do
    RolePlay.delete_all

    active = RolePlay.create!(
      name: "Active Scenario",
      description: "Test",
      llm_instructions: "Test",
      duration_minutes: 10,
      recommended_for: "Test",
      category: :communication,
      active: true
    )

    inactive = RolePlay.create!(
      name: "Inactive Scenario",
      description: "Test",
      llm_instructions: "Test",
      duration_minutes: 10,
      recommended_for: "Test",
      category: :communication,
      active: false
    )

    scope = Pundit.policy_scope!(@regular_account_user, RolePlay)
    assert_includes scope, active
    assert_includes scope, inactive
  end
end
