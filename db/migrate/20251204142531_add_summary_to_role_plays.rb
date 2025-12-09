class AddSummaryToRolePlays < ActiveRecord::Migration[8.1]
  SUMMARIES = {
    "Clarity of Role" => "Transform from doer to leader, fostering clarity, purpose, and boundaries for a confident, empowered team.",
    "Communication Skills" => "Communicate with clarity and confidence, ensuring true alignment and reducing misunderstandings in every interaction.",
    "Feedback and Coaching" => "Drive growth through constructive feedback, building trust and confidence while ensuring high performance standards.",
    "Confidence with Conflict" => "Address performance issues early with empathy and clarity, fostering trust and improving team dynamics.",
    "Team Culture Building" => "Shape a culture of trust and inclusion by addressing micro-behaviors and reinforcing team norms.",
    "Resilience and Capability Building" => "Delegate stretch tasks confidently, building team capability while nurturing resilience and independence.",
    "Team Culture Building 2" => "Inspire and motivate disengaged team members by connecting with their intrinsic motivations and addressing obstacles.",
    "Other Example Role Play 2" => "Manage your relationship with leadership effectively, advocating for yourself while advancing your goals."
  }.freeze

  def up
    add_column :role_plays, :summary, :string

    SUMMARIES.each do |name, summary|
      execute <<-SQL.squish
        UPDATE role_plays SET summary = #{connection.quote(summary)} WHERE name = #{connection.quote(name)}
      SQL
    end
  end

  def down
    remove_column :role_plays, :summary
  end
end
