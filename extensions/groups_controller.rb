module GroupsControllerPavilionExtension
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