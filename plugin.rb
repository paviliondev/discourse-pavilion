# name: discourse-pavilion
# about: Pavilion customisations
# version: 0.2
# authors: Angus McLeod
# url: https://github.com/angusmcleod/discourse-pavilion

register_asset "stylesheets/common/pavilion.scss"
register_asset "stylesheets/mobile/pavilion.scss", :mobile

if respond_to?(:register_svg_icon)
  register_svg_icon "hard-hat"
  register_svg_icon "dollar-sign"
end

after_initialize do
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
  
  class HomepageUserSerializer < ::BasicUserSerializer
    attributes :title, :bio
    
    def bio
      object.user_profile.bio_processed
    end
  end
  
  require_dependency 'topic_list_item_serializer'
  class HomeTopicListItemSerializer < ::TopicListItemSerializer
    def excerpt
      doc = Nokogiri::HTML::fragment(object.first_post.cooked)
      doc.search('.//img').remove
      PrettyText.excerpt(doc.to_html, 300, keep_emoji_images: true)
    end

    def include_excerpt?
      true
    end
  end
  
  require_dependency 'topic_list_serializer'
  class HomeTopicListSerializer < ::TopicListSerializer
    has_many :topics, serializer: HomeTopicListItemSerializer, embed: :objects
  end  
  
  require_dependency 'application_controller'
  require_dependency 'user_serializer'
  class PavilionHome::PageController < ::ApplicationController    
    def index
      json = {}
      guardian = Guardian.new(current_user)
      
      about_category = Category.find_by(name: 'About') ||  Category.find_by(id: 1)
      team_group = Group.find_by(name: SiteSetting.pavilion_team_group)
      
      if team_group
        json[:members] = ActiveModel::ArraySerializer.new(
          team_group.users.sample(2),
          each_serializer: UserSerializer,
          scope: guardian
        )
      end
            
      if current_user
        topic_list_opts = {
          limit: 6
        }
        
        if current_user.staff? || current_user.home_category
          if current_user.home_category
            topic_list_opts[:category] = current_user.home_category.id
          end
                  
          topic_list = TopicQuery.new(current_user, topic_list_opts).list_latest
          
          json[:topic_list] = serialize_data(topic_list, TopicListSerializer, scope: guardian)
        end
      end
        
      if about_topic_list = TopicQuery.new(current_user,
          per_page: 3,
          category: about_category.id,
          no_definitions: true
        ).list_latest
        
        json[:about_topic_list] = HomeTopicListSerializer.new(about_topic_list,
          scope: guardian
        ).as_json
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
  
  Group.register_custom_field_type('client_group', :boolean)
  Group.preloaded_custom_fields << "client_group" if Group.respond_to? :preloaded_custom_fields
  
  module ClientGroupModelExtension
    def expire_cache
      super
      @client_groups = nil
    end
  end
  
  require_dependency 'group'
  class ::Group
    prepend ClientGroupModelExtension

    def client_group
      if custom_fields['client_group'] != nil
        custom_fields['client_group']
      else
        false
      end
    end
    
    def self.client_groups
      @client_groups ||= begin
        Group.where("groups.id in (
          SELECT group_id FROM group_custom_fields
          WHERE name = 'client_group' AND
          value::boolean IS TRUE
        )")
      end
    end
  end
  
  require_dependency 'category'
  class ::Category
    def self.client_group_category(group_id)
      Category.where("categories.id in (
        SELECT category_id FROM category_groups
        WHERE group_id = #{group_id}
        AND permission_type = 1
      )").first
    end
  end
  
  module FeatureGroupUserExtension
    def reload
      @client_groups = nil
      super
    end
  end
  
  require_dependency 'user'
  class ::User
    prepend FeatureGroupUserExtension

    def home_category
      if client_groups.present?
        Category.client_group_category(client_groups.pluck(:id).first)
      end
    end
    
    def client_groups
      Group.member_of(Group.client_groups, self)
    end
    
    def member
      Group.member_of(Group.where(name: SiteSetting.pavilion_team_group), self)
    end
  end
  
  module AdminGroupsControllerExtension
    private def group_params
      client_group = params.require(:group).permit(:client_group)[:client_group]

      if client_group != nil
        merge_params = {
          custom_fields: { client_group: client_group }
        }
        super.merge(merge_params)
      else
        super
      end
    end
  end

  module GroupsControllerExtension
    private def group_params(automatic: false)
      client_group = params.require(:group).permit(:client_group)[:client_group]

      if client_group != nil
        merge_params = {
          custom_fields: { client_group: client_group }
        }
        super.merge(merge_params)
      else
        super
      end
    end
  end

  require_dependency 'admin/groups_controller'
  class ::Admin::GroupsController
    prepend AdminGroupsControllerExtension
  end

  require_dependency 'groups_controller'
  class ::GroupsController
    prepend GroupsControllerExtension
  end
  
  add_to_serializer(:basic_group, :client_group) { object.client_group }
  
  module ::PavilionWork
    class Engine < ::Rails::Engine
      engine_name "pavilion_work"
      isolate_namespace PavilionWork
    end
  end 
  
  PavilionWork::Engine.routes.draw do
    put 'update' => 'work#update'
  end
  
  Discourse::Application.routes.append do
    mount ::PavilionWork::Engine, at: 'work'
    %w{users u}.each_with_index do |root_path, index|
      get "#{root_path}/:username/work" => "pavilion_work/work#index", constraints: { username: RouteFormat.username }
    end
    
    scope module: 'pavilion_work', constraints: StaffConstraint.new do
      get 'admin/work' => 'admin#index'
    end
  end
  
  class PavilionWork::WorkController < ::ApplicationController
    def index
    end

    def update
      user_fields = params.permit(:earnings_target_month)
      user = current_user
      
      user_fields.each do |field, value|
        user_fields[field] = value.to_i
        
        if user_fields[field] > SiteSetting.send("max_#{field}".to_sym)
          raise Discourse::InvalidParameters.new(field.to_sym)
        end
      end
      
      user_fields.each do |field, value|
        user.custom_fields[field] = value
      end
      
      user.save_custom_fields(true)
      
      result = {}
      
      user_fields.each do |field|
        value = user.custom_fields[field]
        result[field] = value if value.present?
      end
      
      render json: success_json.merge(result)
    end
  end
  
  class PavilionWork::AdminController < ::Admin::AdminController
    def index
      if params[:month] && params[:year]
        mi = params[:month].to_i
        render_json_dump(
          success: true,
          current_month: month_data(mi),
          previous_month: month_data(mi === 1 ? 12 : mi - 1),
          next_month: month_data(mi === 12 ? 1 : mi + 1)
        )
      else
        render json: failed_json
      end
    end
    
    def month_data(month)
      ActiveModel::ArraySerializer.new(
        PavilionWork::Members.month_totals(
          month: month,
          year: params[:year].to_i
        ),
        each_serializer: PavilionWork::MemberSerializer
      )
    end
  end
  
  class PavilionWork::Members
    
    ## TODO: turn this into a single SQL query
    
    def self.month_totals(opts)
      month = Date.strptime("#{opts[:month].to_s}/#{opts[:year].to_s}", "%m/%Y")
      month_start = month.at_beginning_of_month
      month_end = month.at_end_of_month
      members = Group.find_by(name: 'members').users
          
      members.reduce([]) do |result, user|     
        assigned_topics = assigned_in_month(user, month_start, month_end)
                        
        if assigned_topics.any?
          billable_total_month = assigned_topics.map do |topic|
            topic.billable_hours.to_f * topic.billable_hour_rate.to_f
          end.inject(0, &:+)
                    
          result.push(
            user: user,
            billable_total_month: billable_total_month,
            month: month.strftime("%Y-%m")
          )
        end
        
        result
      end
    end
    
    def self.assigned_in_month(user, month_start, month_end)
      TopicQuery.new(Discourse.system_user, 
        assigned: user.username,
        start: month_start,
        end: month_end
      ).list_latest.topics
    end
  end
  
  class PavilionWork::MemberSerializer < ::ApplicationSerializer
    attributes :user,
               :billable_total_month,
               :earnings_target_month,
               :month
    
    def user
      BasicUserSerializer.new(object[:user], root: false).as_json
    end
    
    def billable_total_month
      object[:billable_total_month].to_i
    end
    
    def earnings_target_month
      object[:user].custom_fields['earnings_target_month']
    end
    
    def month
      object[:month]
    end
  end
  
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
  
  add_to_serializer(:site_category, :latest_post_created_at) { object.latest_post&.created_at }
end
