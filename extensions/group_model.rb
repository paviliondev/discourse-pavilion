module GroupModelPavilionExtension
  def expire_cache
    super
    @client_groups = nil
  end
  
  def self.prepended(klass)
    klass.singleton_class.send(:alias_method, :core_visible_groups, :visible_groups)
    klass.instance_eval do
      scope :visible_groups, Proc.new { |user, order, opts|
        Group.from("
          (
            (#{core_visible_groups(user).to_sql})
            
            UNION 
            
            SELECT * FROM (#{client_groups.to_sql}) AS client_groups
            WHERE EXISTS(
               SELECT 1
               FROM groups g
               JOIN group_users gu ON gu.group_id = g.id
               AND gu.user_id = #{user ? user.id : -3}
               AND g.name IN ('#{SiteSetting.pavilion_can_see_client_groups.split('|').join(',')}')
            )
          ) AS groups
        ")
      }
      scope :client_groups, -> {
        where("
          groups.id IN (
            SELECT group_id FROM group_custom_fields
            WHERE name = 'client_group' AND
            value::boolean IS TRUE
          )
        ")
      }
    end
  end
end