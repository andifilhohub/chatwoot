class AccountFeaturesField < Administrate::Field::Base
  def grouped_features
    regular, premium = available_features.partition { |feature| !feature['premium'] }
    { regular: regular, premium: premium }
  end

  def feature_enabled?(feature_name)
    data&.fetch(feature_name.to_s, false)
  end

  def feature_display_name(feature)
    feature['display_name'].presence || feature['name'].to_s.humanize
  end

  private

  def available_features
    features = SuperAdmin::AccountFeaturesHelper.account_features
    features = features.reject { |feature| feature['deprecated'] }
    features = features.reject { |feature| feature['chatwoot_internal'] } unless ChatwootApp.chatwoot_cloud?
    features
  end
end
