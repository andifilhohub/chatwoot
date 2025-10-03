# frozen_string_literal: true

# Load GeniusCloud customizations without touching core Chatwoot files.
# GeniusCloud-modify directory was removed
genius_cloud_app_path = nil

if false # genius_cloud_app_path.exist?
  Rails.autoloaders.main.push_dir(genius_cloud_app_path)

  views_path = genius_cloud_app_path.join('views')
  ActionController::Base.prepend_view_path(views_path) if views_path.exist?

  Rails.application.config.watchable_dirs[genius_cloud_app_path.to_s] = %i[rb erb haml slim js vue]
  
  # Ensure GeniusCloud models are autoloaded
  Rails.application.config.to_prepare do
    Dir[genius_cloud_app_path.join('models', '**', '*.rb')].each do |file|
      require_dependency file
    end
  end
end

# Allow GeniusCloud specific routes to live outside the core `config/routes.rb`.
# GeniusCloud-modify directory was removed
genius_cloud_routes_path = nil
if false # genius_cloud_routes_path.exist?
  Rails.application.routes.append do
    instance_eval(File.read(genius_cloud_routes_path), genius_cloud_routes_path.to_s)
  end

  reloader = ActiveSupport::FileUpdateChecker.new([genius_cloud_routes_path]) do
    Rails.application.routes_reloader.execute_if_updated
    Rails.application.reload_routes!
  end
  Rails.application.reloaders << reloader
end
