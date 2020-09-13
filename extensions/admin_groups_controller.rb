module AdminGroupsControllerPavilionExtension
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