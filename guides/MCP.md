# MCP Server

PgHero ships with a built-in [MCP](https://modelcontextprotocol.io) server, so AI assistants like Claude can inspect database performance — running queries, query stats, explain plans, indexes, space usage, maintenance, and more.

- communicates over stdio — no HTTP server or extra port needed
- no additional dependencies
- **read-only** — tools never modify the database

## Setup

The server uses the same configuration as the gem. For a quick start, set:

```sh
PGHERO_DATABASE_URL=postgres://user:password@hostname/dbname
```

For more control (multiple databases, thresholds, cloud stats), create `config/pghero.yml`:

```yml
databases:
  main:
    url: postgres://user:password@hostname/dbname
  replica:
    url: postgres://user:password@replica-hostname/dbname
```

Set the path with the `PGHERO_CONFIG_PATH` environment variable if it’s not `config/pghero.yml` relative to the current directory. Inside a Rails app, run `bundle exec pghero-mcp` to use the app’s configuration.

See the [Rails guide](Rails.md) for the full list of options.

## Run

```sh
pghero-mcp
```

The server reads JSON-RPC messages on stdin and writes responses to stdout.

## Claude Code

```sh
claude mcp add pghero -- pghero-mcp
```

Or with a connection string:

```sh
claude mcp add pghero --env PGHERO_DATABASE_URL=postgres://user:password@hostname/dbname -- pghero-mcp
```

## Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "pghero": {
      "command": "pghero-mcp",
      "env": {
        "PGHERO_DATABASE_URL": "postgres://user:password@hostname/dbname"
      }
    }
  }
}
```

## Cursor

Add to `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "pghero": {
      "command": "pghero-mcp",
      "env": {
        "PGHERO_DATABASE_URL": "postgres://user:password@hostname/dbname"
      }
    }
  }
}
```

## Tools

All tools accept an optional `database` argument (the database id) and default to the first configured database.

- `databases` - list configured databases
- `overview` - size, hit rates, connections, replication, and problem counts
- `running_queries` - currently running queries
- `long_running_queries` - queries past the long-running threshold
- `blocked_queries` - queries blocked by locks
- `query_stats` - pg_stat_statements stats (requires the pg_stat_statements extension)
- `query_stats_status` - whether query stats are available
- `query_details` - historical stats for a query (requires stats capture)
- `explain` - EXPLAIN plan without executing the query (never uses ANALYZE)
- `indexes` - all indexes, filterable by schema and table
- `invalid_indexes` - indexes that are not valid
- `duplicate_indexes` - redundant indexes
- `unused_indexes` - indexes with little or no use
- `index_usage` - index usage per table
- `index_bloat` - bloat estimates for indexes
- `missing_indexes` - tables likely missing indexes
- `caching` - cache hit rates
- `unused_tables` - tables with no index scans
- `table_stats` - rows and size per table
- `space` - database and relation sizes
- `space_growth` - relation growth (requires space stats capture)
- `relation_space_stats` - size history for a relation (requires space stats capture)
- `maintenance` - vacuum and analyze info, transaction id danger
- `settings` - server settings
- `connections` - connections by state and source
- `replication` - replica status, lag, and slots
- `sequences` - sequence usage and exhaustion danger
- `invalid_constraints` - constraints that are not valid
- `suggested_indexes` - suggested indexes from query stats (requires the pg_query gem)
- `best_index` - best index for a query (requires the pg_query gem)
- `system_stats` - cloud system stats (requires AWS or GCP config)

## Security

All tools are read-only. Mutating operations (kill queries, reset stats, capture stats, analyze tables, and autoindex) are intentionally not exposed, and `explain` never executes the query being explained.

The server runs locally and connects with the credentials you provide, so access is limited to what those credentials allow. Use a read-only database user for extra safety.

## History

View the [changelog](../CHANGELOG.md).
