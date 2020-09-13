module UserModelPavilionExtension
  def reload
    @client_groups = nil
    super
  end
end