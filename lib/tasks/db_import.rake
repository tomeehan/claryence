require 'shellwords'

namespace :db do
  namespace :import do
    desc "Download latest Heroku production backup and restore into local primary DB (development)"
    task production: :environment do
      DbImport.from_heroku_app!("claryence-production")
    end

    desc "Download latest Heroku staging backup and restore into local primary DB (development)"
    task staging: :environment do
      DbImport.from_heroku_app!("claryence-staging")
    end
  end
end

module DbImport
  module_function

  def from_heroku_app!(app)
    ensure_cli!("heroku")
    ensure_cli!("pg_restore")

    timestamp = Time.now.utc.strftime("%Y%m%d-%H%M%S")
    dump_path = Rails.root.join("tmp", "#{app}-#{timestamp}.dump")
    FileUtils.mkdir_p(dump_path.dirname)

    puts "==> Capturing latest backup on Heroku (#{app})"
    run!("heroku pg:backups:capture --app #{Shellwords.escape(app)}")
    wait_for_backup!(app)

    puts "==> Downloading latest backup to #{dump_path}"
    # Prefer explicit output path where supported; fallback to default filename
    download_cmd = "heroku pg:backups:download --app #{Shellwords.escape(app)} -o #{Shellwords.escape(dump_path.to_s)}"
    unless run(download_cmd)
      # Fallback without -o, then move file if present
      run!("heroku pg:backups:download --app #{Shellwords.escape(app)}")
      default_file = Rails.root.join("latest.dump")
      FileUtils.mv(default_file, dump_path) if File.exist?(default_file)
    end

    cfg = primary_db_config
    puts "==> Restoring into local DB: #{cfg[:database]} (host=#{cfg[:host] || 'localhost'}, user=#{cfg[:username] || ENV['USER']})"

    env = {}
    env["PGPASSWORD"] = cfg[:password] if cfg[:password]
    # Ensure DB exists (pg_restore --clean will recreate objects)
    ensure_database_exists!(cfg)

    args = []
    args += ["-h", cfg[:host]] if cfg[:host]
    args += ["-p", cfg[:port].to_s] if cfg[:port]
    args += ["-U", cfg[:username]] if cfg[:username]
    args += ["-d", cfg[:database]]
    args += ["--verbose", "--clean", "--no-acl", "--no-owner", dump_path.to_s]

    puts "==> Running pg_restore"
    unless run_pg_restore(args, env)
      puts "!! Local pg_restore failed. Attempting Dockerized pg_restore (Postgres 16)."
      unless docker_available?
        abort <<~MSG
          pg_restore failed and Docker is not available.
          You likely need a newer PostgreSQL client.
          Try: brew install postgresql@16 && export PATH=\"/opt/homebrew/opt/postgresql@16/bin:$PATH\" (on macOS)
          Or install Docker and re-run the task.
        MSG
      end

      unless run_docker_pg_restore(dump_path, cfg)
        abort "Dockerized pg_restore also failed. See output above."
      end
    end

    puts "==> Done. Imported backup from #{app} into #{cfg[:database]}"
  ensure
    # Keep the dump for inspection; uncomment to auto-delete
    # FileUtils.rm_f(dump_path) if dump_path && File.exist?(dump_path)
  end

  def wait_for_backup!(app)
    puts "==> Waiting for backup to complete on Heroku (#{app})"
    started_at = Time.now
    timeout = (ENV["HEROKU_BACKUP_TIMEOUT"] || 600).to_i # default 10 minutes
    interval = (ENV["HEROKU_BACKUP_POLL_INTERVAL"] || 5).to_i

    loop do
      info_cmd = "heroku pg:backups:info --app #{Shellwords.escape(app)}"
      output = `#{info_cmd} 2>&1`
      if $?.success? && output.include?("Completed")
        puts "==> Backup marked Completed"
        return
      end
      if output =~ /(Failed|Error)/i
        abort "Heroku backup failed or errored:\n#{output}"
      end
      if Time.now - started_at > timeout
        puts "==> Timed out waiting for backup. Proceeding to download attempt."
        return
      end
      sleep interval
    end
  end

  def primary_db_config
    # Target local development primary database
    config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
    if config
      cfg = config.configuration_hash.symbolize_keys
    else
      # Fallback to current connection
      dbc = ActiveRecord::Base.connection_db_config
      cfg = dbc.configuration_hash.symbolize_keys
    end
    {
      database: cfg[:database] || ENV["PGDATABASE"],
      host: cfg[:host] || ENV["PGHOST"],
      port: cfg[:port] || (ENV["PGPORT"]&.to_i),
      username: cfg[:username] || ENV["PGUSER"],
      password: cfg[:password] || ENV["PGPASSWORD"],
    }
  end

  def ensure_database_exists!(cfg)
    # Try to create DB if it doesn't exist
    createdb_args = []
    createdb_args += ["-h", cfg[:host]] if cfg[:host]
    createdb_args += ["-p", cfg[:port].to_s] if cfg[:port]
    createdb_args += ["-U", cfg[:username]] if cfg[:username]
    createdb_args << cfg[:database]
    run("createdb #{createdb_args.shelljoin}", (cfg[:password] ? {"PGPASSWORD" => cfg[:password]} : {}))
  end

  def run_pg_restore(args, env)
    cmd = "pg_restore #{args.shelljoin}"
    puts "$ #{cmd}"
    system(env, cmd)
  end

  def docker_available?
    system("which docker >/dev/null 2>&1")
  end

  def run_docker_pg_restore(dump_path, cfg)
    dump_basename = File.basename(dump_path.to_s)
    # Mount tmp so container can read the downloaded dump
    host_dir = Rails.root.join("tmp").to_s
    pgpw = cfg[:password]
    env = pgpw ? ["-e", "PGPASSWORD=#{pgpw}"] : []

    host = cfg[:host]
    # If host not specified or is localhost, use Docker's host gateway
    if host.nil? || host == "localhost" || host == "127.0.0.1"
      host = "host.docker.internal"
    end

    cmd = [
      "docker", "run", "--rm",
      *env,
      "-v", "#{host_dir}:/tmp",
      "postgres:16-alpine",
      "pg_restore",
      "-h", host
    ]
    cmd += ["-p", cfg[:port].to_s] if cfg[:port]
    cmd += ["-U", cfg[:username]] if cfg[:username]
    cmd += ["-d", cfg[:database]]
    cmd += ["--verbose", "--clean", "--no-acl", "--no-owner", "/tmp/#{dump_basename}"]

    puts "$ #{cmd.shelljoin}"
    system(cmd.shelljoin)
  end

  def ensure_cli!(cmd)
    return if system("which #{cmd} >/dev/null 2>&1")
    abort "Missing required CLI: #{cmd}. Please install it and ensure it's on your PATH."
  end

  def run!(command, env = {})
    puts "$ #{command}"
    success = system(env, command)
    abort "Command failed: #{command}" unless success
    true
  end

  def run(command, env = {})
    puts "$ #{command}"
    system(env, command)
  end
end
