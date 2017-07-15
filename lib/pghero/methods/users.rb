module PgHero
  module Methods
    module Users
      def create_user(user, password: nil, schema: "public", database: nil, readonly: false, tables: nil)
        password ||= random_password
        database ||= connection_model.connection_config[:database]

        commands =
          [
            "CREATE ROLE #{user} LOGIN PASSWORD #{quote(password)}",
            "GRANT CONNECT ON DATABASE #{database} TO #{user}",
            "GRANT USAGE ON SCHEMA #{schema} TO #{user}"
          ]
        if readonly
          if tables
            commands.concat table_grant_commands("SELECT", tables, user)
          else
            commands << "GRANT SELECT ON ALL TABLES IN SCHEMA #{schema} TO #{user}"
            commands << "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} GRANT SELECT ON TABLES TO #{user}"
          end
        else
          if tables
            commands.concat table_grant_commands("ALL PRIVILEGES", tables, user)
          else
            commands << "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA #{schema} TO #{user}"
            commands << "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA #{schema} TO #{user}"
            commands << "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} GRANT ALL PRIVILEGES ON TABLES TO #{user}"
            commands << "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} GRANT ALL PRIVILEGES ON SEQUENCES TO #{user}"
          end
        end

        # run commands
        connection_model.transaction do
          commands.each do |command|
            execute command
          end
        end

        {password: password}
      end

      def drop_user(user, schema: "public", database: nil)
        database ||= connection_model.connection_config[:database]

        # thanks shiftb
        commands =
          [
            "REVOKE CONNECT ON DATABASE #{database} FROM #{user}",
            "REVOKE USAGE ON SCHEMA #{schema} FROM #{user}",
            "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA #{schema} FROM #{user}",
            "REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA #{schema} FROM #{user}",
            "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} REVOKE SELECT ON TABLES FROM #{user}",
            "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} REVOKE SELECT ON SEQUENCES FROM #{user}",
            "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} REVOKE ALL ON SEQUENCES FROM #{user}",
            "ALTER DEFAULT PRIVILEGES IN SCHEMA #{schema} REVOKE ALL ON TABLES FROM #{user}",
            "DROP ROLE #{user}"
          ]

        # run commands
        connection_model.transaction do
          commands.each do |command|
            execute command
          end
        end

        true
      end

      private

      def random_password
        require "securerandom"
        SecureRandom.base64(40).delete("+/=")[0...24]
      end

      def table_grant_commands(privilege, tables, user)
        tables.map do |table|
          "GRANT #{privilege} ON TABLE #{table} TO #{user}"
        end
      end
    end
  end
end
