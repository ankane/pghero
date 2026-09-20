require_relative "test_helper"
require "pghero/mcp"

class McpTest < Minitest::Test
  def setup
    @server = PgHero::MCP::Server.new(input: StringIO.new, output: StringIO.new)
  end

  def test_initialize
    response = handle({"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => {"protocolVersion" => "2025-06-18"}})
    assert_equal 1, response["id"]
    assert_equal "pghero", response.dig("result", "serverInfo", "name")
    assert_equal PgHero::VERSION, response.dig("result", "serverInfo", "version")
    assert_equal "2025-06-18", response.dig("result", "protocolVersion")
    assert response.dig("result", "capabilities", "tools")
  end

  def test_initialize_unsupported_protocol_version
    response = handle({"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => {"protocolVersion" => "1999-01-01"}})
    assert_equal PgHero::MCP::Server::LATEST_PROTOCOL_VERSION, response.dig("result", "protocolVersion")
  end

  def test_ping
    response = handle({"jsonrpc" => "2.0", "id" => 2, "method" => "ping"})
    assert_equal({"jsonrpc" => "2.0", "id" => 2, "result" => {}}, response)
  end

  def test_unknown_method
    response = handle({"jsonrpc" => "2.0", "id" => 3, "method" => "unknown/method"})
    assert_equal(-32601, response.dig("error", "code"))
  end

  def test_notification_no_response
    assert_nil handle({"jsonrpc" => "2.0", "method" => "notifications/initialized"})
  end

  def test_tools_list
    response = handle({"jsonrpc" => "2.0", "id" => 4, "method" => "tools/list"})
    tools = response.dig("result", "tools")
    names = tools.map { |t| t["name"] }
    assert_includes names, "running_queries"
    assert_includes names, "suggested_indexes"
    assert_equal 31, tools.size
    tools.each do |tool|
      assert tool["description"], "#{tool["name"]} has a description"
      schema = tool["inputSchema"]
      assert_equal "object", schema["type"]
      assert schema["properties"]
    end
  end

  def test_run
    input = StringIO.new([
      JSON.generate({"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => {}}),
      JSON.generate({"jsonrpc" => "2.0", "method" => "notifications/initialized"}),
      JSON.generate({"jsonrpc" => "2.0", "id" => 2, "method" => "ping"}),
      ""
    ].join("\n"))
    output = StringIO.new
    PgHero::MCP::Server.new(input: input, output: output).run
    responses = output.string.split("\n").map { |l| JSON.parse(l) }
    assert_equal 2, responses.size
    assert_equal 2, responses.last["id"]
  end

  def test_tool_call_databases
    result = call_tool("databases")
    assert_equal "primary", result.first["id"]
  end

  def test_tool_call_overview
    result = call_tool("overview")
    assert_equal database.database_name, result["database_name"]
    assert_match(/\A[\d.]+ [KMG]?B\z/, result["database_size"])
    refute result["replica"]
  end

  def test_tool_call_running_queries
    result = call_tool("running_queries")
    assert_kind_of Array, result
  end

  def test_tool_call_indexes
    result = call_tool("indexes", {"table" => "users"})
    refute_empty result
    result.each do |index|
      assert_equal "users", index["table"]
    end
  end

  def test_tool_call_explain
    result = call_tool("explain", {"sql" => "SELECT * FROM users WHERE id = 1"})
    assert_match(/Scan/, result)
  end

  def test_tool_call_unknown_database
    response = call_tool_raw("overview", {"database" => "nope"})
    assert response.dig("result", "isError")
    assert_match "Database not found", response.dig("result", "content", 0, "text")
  end

  def test_tool_call_unknown_tool
    response = call_tool_raw("nope")
    assert_equal(-32602, response.dig("error", "code"))
  end

  private

  def handle(message)
    @server.handle_message(message)
  end

  def call_tool_raw(name, arguments = {})
    handle({"jsonrpc" => "2.0", "id" => 1, "method" => "tools/call", "params" => {"name" => name, "arguments" => arguments}})
  end

  def call_tool(name, arguments = {})
    JSON.parse(call_tool_raw(name, arguments).dig("result", "content", 0, "text"))
  end
end
