# name: discourse-pavilion
# about: Pavilion customisations
# version: 0.1
# authors: Angus McLeod
# url: https://github.com/angusmcleod/discourse-pavilion

register_asset "stylesheets/common/pavilion.scss"
register_asset "stylesheets/mobile/pavilion.scss", :mobile

Discourse.filters.push(:work)
Discourse.anonymous_filters.push(:work)

Discourse.filters.push(:unassigned)
Discourse.anonymous_filters.push(:unassigned)

if respond_to?(:register_svg_icon)
  register_svg_icon "hard-hat"
  register_svg_icon "clock-o"
  register_svg_icon "dollar-sign"
  register_svg_icon "funnel-dollar"
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
    attributes :title,
               :bio
    
    def bio
      object.user_profile.bio_processed
    end
  end
  
  TopicQuery.add_custom_filter(:exclude_done) do |topics, query|
    if query.options[:exclude_done]
      topics.where("topics.id NOT IN (
         SELECT topic_id FROM topic_tags
         WHERE topic_tags.tag_id in (
           SELECT id FROM tags
           WHERE tags.name = 'done'
         )
       )")
    else
      topics
    end
  end
  
  TopicQuery.add_custom_filter(:calendar) do |topics, query|
    topics
  end
  
  require_dependency 'topic_query'
  class ::TopicQuery
    def list_unassigned
      @options[:assigned] = "nobody"
      @options[:tags] = SiteSetting.pavilion_unassigned_tags.split('|')
      create_list(:unassigned)
    end
    
    def list_work
      @options[:assigned] = @user.username
      
      create_list(:work) do |result|
        result.where("topics.id NOT IN (
          SELECT topic_id FROM topic_tags
          WHERE topic_tags.tag_id in (
            SELECT id FROM tags
            WHERE tags.name = 'done'
          )
        )")
      end
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
      
      if team_group = Group.find_by(name: SiteSetting.pavilion_team_group)
        json[:members] = ActiveModel::ArraySerializer.new(
          team_group.users.sample(2),
          each_serializer: UserSerializer,
          scope: guardian
        )
      end
      
      topic_list = nil
      
      if current_user && current_user.staff?
        topic_list = TopicQuery.new(current_user,
          per_page: 6,
          exclude_done: true,
          assigned: current_user.username
        ).list_latest
      elsif (current_user && (home_category = current_user.home_category))
        topic_list = TopicQuery.new(current_user,
          category: home_category.id,
          per_page: 6
        ).list_latest
      end
      
      if topic_list
        json[:topic_list] = TopicListSerializer.new(topic_list,
          scope: guardian
        ).as_json
      end
        
      if about_category = Category.find_by(name: 'About')
        if about_topic_list = TopicQuery.new(current_user,
            per_page: 3,
            category: about_category.id,
            no_definitions: true
          ).list_latest
          json[:about_topic_list] = HomeTopicListSerializer.new(about_topic_list,
            scope: guardian
          ).as_json
        end
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
        "work"
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
    'billable_hours',
    'billable_hour_rate'
  ].each do |field|
    Topic.register_custom_field_type(field, :integer)
    add_to_serializer(:topic_view, field.to_sym) { object.topic.custom_fields[field] }
    add_to_serializer(:topic_list_item, field.to_sym) { object.custom_fields[field] }
    TopicList.preloaded_custom_fields << field if TopicList.respond_to? :preloaded_custom_fields
    PostRevisor.track_topic_field(field.to_sym) do |tc, tf|
      tc.record_change(field, tc.topic.custom_fields[field], tf)
      tc.topic.custom_fields[field] = tf
    end
  end
  
  [
    'earnings_target_month'
  ].each do |field|
    User.register_custom_field_type(field, :integer)
    add_to_serializer(:user, field.to_sym) { object.custom_fields[field] }
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
    
    scope module: 'pavilion_work', constraints: AdminConstraint.new do
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
        member_billable_totals = PavilionWork::Members.billable_totals(
          month: params[:month],
          year: params[:year]
        )
        
        render_json_dump(
          members: ActiveModel::ArraySerializer.new(member_billable_totals,
            each_serializer: PavilionWork::MemberSerializer
          ),
          month: params[:month],
          year: params[:year]
        )
      else
        render json: success_json
      end
    end
  end
  
  class PavilionWork::Members
    def self.billable_totals(opts)
      users = Group.find_by(name: 'members').users
      totals = []
      
      users.each do |user|
        month = Date.strptime("#{opts[:month]}/#{opts[:year]}", "%m/%Y")
        assigned = TopicQuery.new(user, 
          assigned: user.username,
          calendar: true,
          start: month.at_beginning_of_month,
          end: month.at_end_of_month
        ).list_latest.topics
                
        if assigned.any?
          billable_total_month = assigned.map do |a|
            a.custom_fields['billable_hours'].to_i * a.custom_fields['billable_hour_rate'].to_i
          end.inject(0, &:+)
          
          totals.push(
            user: user,
            billable_total_month: billable_total_month,
          )
        end
      end
      
      totals
    end
  end
  
  class PavilionWork::MemberSerializer < ::ApplicationSerializer
    attributes :user,
               :billable_total_month,
               :earnings_target_month
    
    def user
      BasicUserSerializer.new(object[:user], root: false).as_json
    end
    
    def billable_total_month
      object[:billable_total_month].to_i
    end
    
    def earnings_target_month
      object[:user].custom_fields['earnings_target_month']
    end
  end
end
