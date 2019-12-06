# name: discourse-pavilion
# about: Pavilion customisations
# version: 0.1
# authors: Angus McLeod
# url: https://github.com/angusmcleod/discourse-pavilion

register_asset "stylesheets/common/pavilion.scss"
register_asset "stylesheets/mobile/pavilion.scss", :mobile

Discourse.filters.push(:assigned)
Discourse.anonymous_filters.push(:assigned)

Discourse.filters.push(:unassigned)
Discourse.anonymous_filters.push(:unassigned)

if respond_to?(:register_svg_icon)
  register_svg_icon "hard-hat"
  register_svg_icon "clock-o"
  register_svg_icon "dollar-sign"
  register_svg_icon "funnel-dollar"
  register_svg_icon "stopwatch"
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
  
  ## Overrides assign plugin method to exclude PMs from 
  
  TopicQuery.add_custom_filter(:exclude_assigned_pms) do |results, topic_query|
    results
  end

  add_to_serializer(:topic_list, 'include_assigned_messages_count?') do
    options = object.instance_variable_get(:@opts)

    if !options.dig(:exclude_assigned_pms) && (assigned_user = options.dig(:assigned))
      scope.can_assign? ||
        assigned_user.downcase == scope.current_user&.username_lower
    end
  end

  add_to_class(:topic_query, :list_assigned) do
    list = joined_topic_user.where("
      topics.id IN (
        SELECT topic_id FROM topic_custom_fields
        WHERE name = 'assigned_to_id'
        AND value = ?)
    ", user.id.to_s)
      .order("topics.bumped_at DESC")
    create_list(:assigned_work, {}, list)
  end
  
  add_to_class(:topic_query, :list_unassigned) do
    @options[:assigned] = "nobody"
    if unassigned_tags = SiteSetting.pavilion_unassigned_tags.split('|')
      @options[:tags] = unassigned_tags
    end
    create_list(:unassigned_work)
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
          if current_user.staff? &&
             SiteSetting.respond_to?(:assign_enabled) &&
             SiteSetting.assign_enabled
            topic_list_opts[:exclude_assigned_pms] = true
            topic_list_opts[:assigned] = current_user.username
          elsif current_user.home_category
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
      elsif homepage_id == 102
        "assigned"
      elsif homepage_id == 103
        "unassigned"
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
  
  [
    'actual_hours',
    'billable_hours',
    'billable_hour_rate'
  ].each do |field|
    add_to_class(:topic, field.to_sym) { custom_fields[field] }
    add_to_serializer(:topic_view, field.to_sym) { object.topic.send(field) }
    add_to_serializer(:topic_list_item, field.to_sym) { object.send(field) }
    TopicList.preloaded_custom_fields << field if TopicList.respond_to? :preloaded_custom_fields 
    PostRevisor.track_topic_field(field.to_sym) do |tc, tf|
      tc.record_change(field, tc.topic.custom_fields[field], tf)
      tc.topic.custom_fields[field] = tf
    end
  end
  
  [
    'actual_hours_target_month',
    'earnings_target_month'
  ].each do |field|
    add_to_class(:user, field.to_sym) { custom_fields[field] }
    add_to_serializer(:user, field.to_sym) { object.send(field) }
    register_editable_user_custom_field field.to_sym if defined? register_editable_user_custom_field
  end
  
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
      user_fields = params.permit(:earnings_target_month, :actual_hours_target_month)
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
          
      members.map do |user|        
        assigned_topics = assigned_in_month(user, month_start, month_end)
                        
        if assigned_topics.any?
          
          billable_total_month = assigned_topics.map do |topic|
            topic.billable_hours.to_f * topic.billable_hour_rate.to_f
          end.inject(0, &:+)
          
          actual_hours_month = assigned_topics.map do |topic|
            topic.actual_hours.to_f
          end.inject(0, &:+)
                    
          {
            user: user,
            billable_total_month: billable_total_month,
            actual_hours_month: actual_hours_month,
            month: month.strftime("%Y-%m")
          }
        end
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
               :actual_hours_month,
               :actual_hours_target_month,
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
    
    def actual_hours_month
      object[:actual_hours_month].to_i
    end
    
    def actual_hours_target_month
      object[:user].custom_fields['actual_hours_target_month']
    end
    
    def month
      object[:month]
    end
  end
end
