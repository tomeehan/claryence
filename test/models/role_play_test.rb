require "test_helper"

class RolePlayTest < ActiveSupport::TestCase
  # Validation Tests
  test "should be valid with all required attributes" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication,
      active: true
    )
    assert role_play.valid?
  end

  test "should require name" do
    role_play = RolePlay.new(
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication
    )
    assert_not role_play.valid?
    assert_includes role_play.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    existing = RolePlay.create!(
      name: "Unique Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication
    )

    duplicate = RolePlay.new(
      name: "Unique Scenario",
      description: "Different description",
      llm_instructions: "Different instructions",
      duration_minutes: 15,
      recommended_for: "Different recommendation",
      category: :team_management
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should require description" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication
    )
    assert_not role_play.valid?
    assert_includes role_play.errors[:description], "can't be blank"
  end

  test "should require llm_instructions" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication
    )
    assert_not role_play.valid?
    assert_includes role_play.errors[:llm_instructions], "can't be blank"
  end

  test "should require recommended_for" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      category: :communication
    )
    assert_not role_play.valid?
    assert_includes role_play.errors[:recommended_for], "can't be blank"
  end

  test "should require duration_minutes" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      recommended_for: "Test recommendation",
      category: :communication
    )
    assert_not role_play.valid?
    assert_includes role_play.errors[:duration_minutes], "can't be blank"
  end

  test "should require positive duration_minutes" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 0,
      recommended_for: "Test recommendation",
      category: :communication
    )
    assert_not role_play.valid?
    assert_includes role_play.errors[:duration_minutes], "must be greater than 0"
  end

  test "should reject negative duration_minutes" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: -5,
      recommended_for: "Test recommendation",
      category: :communication
    )
    assert_not role_play.valid?
    assert_includes role_play.errors[:duration_minutes], "must be greater than 0"
  end

  test "should require integer duration_minutes" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10.5,
      recommended_for: "Test recommendation",
      category: :communication
    )
    assert_not role_play.valid?
    assert_includes role_play.errors[:duration_minutes], "must be an integer"
  end

  test "should require category" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation"
    )
    assert_not role_play.valid?
    assert_includes role_play.errors[:category], "can't be blank"
  end

  test "should default active to true" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication
    )
    assert role_play.valid?
    # Active defaults to true in the database
  end

  # Enum Tests
  test "should have valid category enums" do
    assert_equal RolePlay.categories.keys, %w[communication team_management conflict_resolution performance_management leadership_development]
  end

  test "should accept communication category" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication
    )
    assert role_play.valid?
    assert_equal "communication", role_play.category
  end

  test "should accept team_management category" do
    role_play = RolePlay.new(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :team_management
    )
    assert role_play.valid?
    assert_equal "team_management", role_play.category
  end

  # Scope Tests
  test "should order by created_at ascending by default" do
    RolePlay.delete_all

    first = RolePlay.create!(
      name: "First Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication,
      created_at: 3.days.ago
    )

    second = RolePlay.create!(
      name: "Second Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication,
      created_at: 2.days.ago
    )

    third = RolePlay.create!(
      name: "Third Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication,
      created_at: 1.day.ago
    )

    role_plays = RolePlay.all.to_a
    assert_equal [first.id, second.id, third.id], role_plays.map(&:id)
  end

  test "active scope should return only active role plays" do
    RolePlay.delete_all

    active = RolePlay.create!(
      name: "Active Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication,
      active: true
    )

    inactive = RolePlay.create!(
      name: "Inactive Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication,
      active: false
    )

    assert_includes RolePlay.active, active
    assert_not_includes RolePlay.active, inactive
  end

  test "by_category scope should filter by category" do
    RolePlay.delete_all

    communication = RolePlay.create!(
      name: "Communication Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication
    )

    team_management = RolePlay.create!(
      name: "Team Management Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :team_management
    )

    results = RolePlay.by_category(:communication)
    assert_includes results, communication
    assert_not_includes results, team_management
  end

  # PaperTrail Tests
  test "should have paper_trail enabled" do
    assert RolePlay.new.respond_to?(:versions)
  end

  test "should track changes with paper_trail" do
    role_play = RolePlay.create!(
      name: "Test Scenario",
      description: "Test description",
      llm_instructions: "Test instructions",
      duration_minutes: 10,
      recommended_for: "Test recommendation",
      category: :communication
    )

    initial_version_count = role_play.versions.count

    role_play.update!(name: "Updated Scenario")
    assert_equal initial_version_count + 1, role_play.versions.count

    role_play.update!(description: "Updated description")
    assert_equal initial_version_count + 2, role_play.versions.count
  end
end
