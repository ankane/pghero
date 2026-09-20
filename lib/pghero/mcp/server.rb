require "json"
require "active_record"
require "active_support/logger"

module PgHero
  module MCP
    class Server
      SUPPORTED_PROTOCOL_VERSIONS = ["2024-11-05", "2025-03-26", "2025-06-18"]
      LATEST_PROTOCOL_VERSION = "2025-06-18"

      class << self
        def run(input: $stdin, output: $stdout)
          # stdout is reserved for the protocol
          output.sync = true

          # keep SQL logs off stdout
          ActiveRecord::Base.logger ||= ActiveSupport::Logger.new($stderr)

          new(input: input, output: output).run
        end
      end

      def initialize(input: $stdin, output: $stdout)
        @input = input
        @output = output
      end

      def run
        @input.each_line do |line|
          next if line.strip.empty?

          begin
            message = JSON.parse(line)
          rescue JSON::ParserError
            next
          end

          response = handle_message(message)
          write(response) if response
        end
      end

      def handle_message(message)
        method = message["method"]
        id = message["id"]

        # notifications don't get a response
        return nil unless method && id

        result =
          case method
          when "initialize"
            initialize_result(message.dig("params", "protocolVersion"))
          when "ping"
            {}
          when "tools/list"
            {"tools" => Tools.definitions}
          when "tools/call"
            Tools.call(message["params"] || {})
          else
            return error_response(id, -32601, "Method not found: #{method}")
          end

        {"jsonrpc" => "2.0", "id" => id, "result" => result}
      rescue Tools::UnknownTool => e
        error_response(id, -32602, e.message)
      rescue => e
        error_response(id, -32603, "#{e.class.name}: #{e.message}")
      end

      private

      def initialize_result(requested_version)
        {
          "protocolVersion" => SUPPORTED_PROTOCOL_VERSIONS.include?(requested_version) ? requested_version : LATEST_PROTOCOL_VERSION,
          "capabilities" => {"tools" => {}},
          "serverInfo" => {"name" => "pghero", "version" => PgHero::VERSION},
          "instructions" => "Read-only PostgreSQL performance insight: running queries, query stats, explain plans, indexes, space usage, maintenance, connections, replication, sequences, settings, and more. Tools never modify the database."
        }
      end

      def error_response(id, code, message)
        {"jsonrpc" => "2.0", "id" => id, "error" => {"code" => code, "message" => message}}
      end

      def write(response)
        @output.puts JSON.generate(response)
      end
    end
  end
end
