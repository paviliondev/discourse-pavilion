# name: discourse-pavilion
# about: Pavilion customisations
# version: 0.2
# authors: Angus McLeod
# url: https://github.com/angusmcleod/discourse-pavilion

register_asset "stylesheets/common/pavilion.scss"

after_initialize do  
  Group.register_custom_field_type('client_group', :boolean)
  Group.preloaded_custom_fields << "client_group" if Group.respond_to? :preloaded_custom_fields
  
  %w{
    ../extensions/guardian.rb
    ../extensions/user_model.rb
    ../extensions/group_model.rb
    ../extensions/admin_groups_controller.rb
    ../extensions/groups_controller.rb
  }.each do |path|
    load File.expand_path(path, __FILE__)
  end
  
  ::User.prepend UserModelPavilionExtension
  ::Group.prepend GroupModelPavilionExtension
  ::Admin::GroupsController.prepend AdminGroupsControllerPavilionExtension
  ::GroupsController.prepend GroupsControllerPavilionExtension
  ::Guardian.prepend GuardianPavilionExtension
  
  add_to_class(:group, :client_group) do
    if custom_fields['client_group'] != nil
      custom_fields['client_group']
    else
      false
    end
  end
  
  add_class_method(:category, :client_group_category) do |group_id|
    Category.where("categories.id in (
      SELECT category_id FROM category_groups
      WHERE group_id = #{group_id}
      AND permission_type = 1
    )").first
  end
  
  add_to_class(:user, :client_groups) do
    Group.member_of(Group.client_groups, self)
  end
  
  add_to_class(:user, :member) do
    Group.member_of(Group.where(name: SiteSetting.pavilion_team_group), self)
  end
  
  add_to_serializer(:basic_group, :client_group) { object.client_group }
  
  on(:topic_created) do |topic, opts, user|
    assignments = {}
    SiteSetting.pavilion_plugin_assignments.split('|').each do |i|
      parts = i.split(':')
      assignments[parts.first] = parts.last
    end
    
    plugin = (topic.tags.pluck(:name) & assignments.keys).first
    
    assignment_category_ids = SiteSetting.pavilion_plugin_assignment_categories.split('|').map(&:to_i)
    is_assignment_category = assignment_category_ids.include?(topic.category_id.to_i)
        
    if plugin && is_assignment_category
      assigner = TopicAssigner.new(topic, Discourse.system_user)
      assigner.assign(User.find_by_username(assignments[plugin]))
    end
  end
  
  LANDING_HOME ||= "/welcome"
  
  add_model_callback(:application_controller, :before_action) do   
    if !current_user &&
        !Discourse.cache.read(landing_page_cache_key(request.remote_ip)) &&
        destination_url == "#{Discourse.base_url}/"
      
      Discourse.cache.write landing_page_cache_key(request.remote_ip), true, expires_in: 10.minutes
      redirect_to LANDING_HOME
      return
    else
      #
    end
  end
  
  GUEST_REDIRECT_CACHE_KEY ||= "landing_pages_has_redirected"
  
  add_to_class(:application_controller, :landing_page_cache_key) do |ip_address|
    "#{GUEST_REDIRECT_CACHE_KEY}_#{ip_address.gsub(/\./, '_')}"
  end
end
