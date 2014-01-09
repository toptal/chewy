module Chewy
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/chewy.rake'
    end

    initializer 'chewy.add_app_chewy_path' do |app|
      app.config.paths.add 'app/chewy'
    end
  end
end
