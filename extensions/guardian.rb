module GroupsMpPavilionExtension
  def can_see_groups?(groups)
    if groups.present? && user.present? && groups.any? { |g| g.client_group }
      groups.all? do |group|
        super([group]) ||
          group.client_group && Group.member_of(
            Group.where(
              name: SiteSetting.pavilion_can_see_client_groups.split('|')
            ),
            user
          )
      end
    else
      super
    end
  end
end