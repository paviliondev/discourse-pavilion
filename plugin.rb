# name: discourse-pavilion
# about: Pavilion customisations
# version: 0.1
# authors: Angus McLeod
# url: https://github.com/angusmcleod/discourse-pavilion

register_asset "stylesheets/common/pavilion.scss"
register_asset "stylesheets/mobile/pavilion.scss", :mobile

after_initialize do
  
  ### Homepage code to be removed on release of Landing Pages plugin
  module ::PavilionHome
    class Engine < ::Rails::Engine
      engine_name "pavilion_home"
      isolate_namespace PavilionHome
    end
  end
  
  require 'homepage_constraint'
  Discourse::Application.routes.prepend do
    root to: "pavilion_home/page#index", constraints: HomePageConstraint.new("home")
    get "/home" => "pavilion_home/page#index"
  end
  
  class ::HomepageUserSerializer < ::BasicUserSerializer
    attributes :title, :bio
    
    def bio
      object.user_profile.bio_processed
    end
  end
  
  class ::HomeTopicListItemSerializer < ::TopicListItemSerializer
    def excerpt
      doc = Nokogiri::HTML::fragment(object.first_post.cooked)
      doc.search('.//img').remove
      PrettyText.excerpt(doc.to_html, 300, keep_emoji_images: true)
    end

    def include_excerpt?
      true
    end
  end
  
  class ::HomeTopicListSerializer < ::TopicListSerializer
    has_many :topics, serializer: HomeTopicListItemSerializer, embed: :objects
  end
  
  class ::PavilionHome::PageController < ::ApplicationController    
    def index
      json = {}
      guardian = Guardian.new(current_user)
      team_group = Group.find_by(name: SiteSetting.pavilion_team_group)
      
      if team_group
        json[:members] = ActiveModel::ArraySerializer.new(
          team_group.users.sample(2),
          each_serializer: UserSerializer,
          scope: guardian
        )
      end
      
      render_json_dump(json)
    end
  end
  
  add_to_serializer(:current_user, :homepage_id) { object.user_option.homepage_id }
  add_to_serializer(:current_user, :member) { object.member }
  add_to_serializer(:user, :member) { object.member }
  
  module UserOptionExtension
    def homepage
      if homepage_id == 101
        "home"
      else
        super
      end
    end
  end
  
  require_dependency 'user_option'
  class ::UserOption
    prepend UserOptionExtension
  end
  
  add_to_class(:user, :home_category) do
    if client_groups.present?
      Category.client_group_category(client_groups.pluck(:id).first)
    end
  end
  
  ##### End of homepage code
  
  Group.register_custom_field_type('client_group', :boolean)
  Group.preloaded_custom_fields << "client_group" if Group.respond_to? :preloaded_custom_fields
  
  %w{
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
  
  assignments = {}
  SiteSetting.pavilion_plugin_assignments.split('|').each do |i|
    parts = i.split(':')
    assignments[parts.last] = parts.first
  end
  
  assignment_category_ids = SiteSetting.pavilion_plugin_assignment_categories.split('|').map(&:to_i)
  
  on(:topic_created) do |topic, opts, user|
    plugin = (topic.tags.pluck(:name) & assignments.keys).first
    assignment_category = assignment_category_ids.include?(topic.category_id.to_i)
        
    if plugin && assignment_category
      assigner = TopicAssigner.new(topic, Discourse.system_user)
      assigner.assign(User.find_by_username(assignments[plugin]))
    end
  end
  
  add_to_serializer(:site_category, :latest_post_created_at) do
    object.latest_post&.created_at
  end
end
