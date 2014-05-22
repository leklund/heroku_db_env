module HerokuDbEnv
  DB_URL_MATCHER = /(.*)_DATABASE_URL/

  class HerokuDbEnvRailtie < Rails::Railtie
    initializer :initialize_heroku_db_env, {:group => :default, :before => "active_record.initialize_database"} do |app|
      db_config = HerokuDbEnv.build_db_config(app.config.database_configuration)

      if db_config.nil?
        ENV["#{Rails.env.upcase}_DATABASE_URL"] = ENV['DATABASE_URL']
      end
      # force active_record to use the db config instead of the db url
      ENV['DATABASE_URL'] = nil

      app.config.class_eval do
        define_method(:database_configuration) { db_config }
      end
    end
  end


class << self

  def build_db_config(default_config = {})
    heroku_config = load_heroku_db_config(Rails.root.join('config/heroku_database.yml'))
    overlay_configs(default_config, heroku_config, env_config)
  end

private

  def load_heroku_db_config(db_yml)
    return {} unless File.exists?(db_yml)
    require 'erb'
    YAML::load(ERB.new(IO.read(db_yml)).result)
  end

  def env_config
    db_env.inject({}) do |a, (env, config)|
      # Rails 4 compatibility
      base = ActiveRecord::Base.const_defined?(:ConnectionSpecification) ?
        ActiveRecord::Base::ConnectionSpecification :
        ActiveRecord::ConnectionAdapters::ConnectionSpecification
      # resolver changed in >4.1
      if base.const_defined?(:ConnectionUrlResolver)
        config_hash = base::ConnectionUrlResolver.new(config).to_hash
      else
         resolver = base::ConnectionSpecification::Resolver.new(config, {})
         config_hash = resolver.spec.config
      end

      a[env.match(DB_URL_MATCHER)[1].downcase] = config_hash; a
    end
  end

  def db_env
    ENV.select { |k,v| DB_URL_MATCHER === k }
  end

  def overlay_configs(*configs)
    configs.inject({}) do |a, c|
      a.deep_merge(c.with_indifferent_access)
    end
  end

end
end
