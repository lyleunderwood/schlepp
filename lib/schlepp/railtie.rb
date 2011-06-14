module Schlepp
  class Railtie < Rails::Railtie
    rake_tasks do
      load "schlepp/tasks/schlepp.rake"
    end

    initializer "setup schlepp" do
      config_file = Rails.root.join("config", "schlepp.rb")
      if config_file.file?
        load config_file
      end
    end

  end
end