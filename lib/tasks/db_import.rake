namespace :db do
  namespace :import do
    desc "Import Heroku Staging database locally"
    task staging: :environment do
      raise "DO NOT RUN THIS ON PRODUCTION!" if Rails.env.production?

      import_db("staging", "claryence-staging")
    end

    # Creates a unique database dump based on the current time and specified environment.
    def import_db(environment, heroku_app_name)
      puts("Importing #{environment} database locally...")
      file = "tmp/#{environment}-#{date}.dump"
      dump_local
      capture_and_download_heroku_db(heroku_app_name)
      `mv latest.dump #{file}`
      import_locally(file)
      run_migrations
      puts("#{environment} database successfully imported")
      reset_passwords
      puts("Admin passwords set to '12345678!!kG'")
    end

    # Returns the readable date in YYYY-MM-DD with an
    # appended integer time to make the filename unique.
    def date
      "#{Time.current.to_date}-#{Time.current.to_i}"
    end

    # Returns the current machine's user for use with PG commands
    def user
      ENV["USER"].try(:strip)
    end

    # Creates and downloads a Heroku database back-up.
    # Requires the Heroku toolchain to be installed and setup.
    def capture_and_download_heroku_db(app)
      `heroku pg:backups:capture --app #{app}`
      `heroku pg:backups:download --app #{app}`
    end

    # Creates a back-up of your current local development
    # database in case you want to restore it.
    def dump_local
      `pg_dump -Fc --no-acl --no-owner -h localhost -U #{user} claryence_development > tmp/development-#{date}.dump`
    end

    # Imports the downloaded database dump into your local development database.
    def import_locally(file)
      pg_restore = pg_restore_path
      `#{pg_restore} --verbose --clean --no-acl --no-owner -h localhost -U #{user} -d claryence_development #{file}`
    end

    # Returns the path to pg_restore, preferring the newest installed version
    def pg_restore_path
      # Check for PostgreSQL 17 first (supports dump format 1.16)
      pg17_path = "/opt/homebrew/opt/postgresql@17/bin/pg_restore"
      return pg17_path if File.exist?(pg17_path)

      # Fall back to default pg_restore
      "pg_restore"
    end

    # Runs migrations against the just imported database dump from Heroku.
    def run_migrations
      `bin/rake db:migrate`
    end

    def reset_passwords
      User.where(admin: true).each do |user|
        user.update!(password: "123123", password_confirmation: "123123")
      end
    end
  end
end
