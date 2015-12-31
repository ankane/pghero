## 1.2.0 [unreleased]

- Added suggested indexes
- Added duplicate indexes
- Added maintenance tab
- Added load stats for RDS
- Added `table_caching` and `index_caching` methods
- Added configurable cache hit rate threshold
- Show all connections in connections tab

## 1.1.4

- Added check for transaction ID wraparound failure
- Added check for autovacuum danger

## 1.1.3

- Fixed system stats

## 1.1.2

- Added invalid indexes
- Fixed RDS stats for aws-sdk 2

## 1.1.1

- Added `tables` option to `create_user` method
- Added ability to sort query stats by average_time and calls
- Only show unused indexes with no index scans in UI

## 1.1.0

- Added historical query stats

## 1.0.1

- Fixed connection bad errors
- Restore previous connection properly for nested with blocks
- Added analyze button to explain page
- Added explain button to live queries page

## 1.0.0

- More platforms!
- Support for multiple databases!
- Added `replica?` method
- Added `replication_lag` method
- Added `ssl_used?` method
- Added `kill_long_running_queries` method
- Added env vars for settings

## 0.1.10

- Added connections page
- Added message for insufficient privilege
- Added `ip` to `connection_sources`

## 0.1.9

- Added tune page
- Removed minimum size for unused indexes

## 0.1.8

- Added `total_percent` to `query_stats`
- Added `total_connections`
- Added `connection_stats` for Amazon RDS

## 0.1.7

- Added support for pg_stat_statments on Amazon RDS
- Added `long_running_query_sec`, `slow_query_ms` and `slow_query_calls` options

## 0.1.6

- Added methods to create and drop users
- Added locks

## 0.1.5

- Added system stats for Amazon RDS
- Added code to remove unused indexes
- Require unused indexes to be at least 1 MB
- Use `pg_terminate_backend` to ensure queries are killed

## 0.1.4

- Reduced long running queries threshold to 1 minute
- Fixed duration
- Fixed wrapping
- Friendlier dependencies for JRuby

## 0.1.3

- Reverted `query_stats_available?` fix

## 0.1.2

- Fixed `query_stats_available?` method

## 0.1.1

- Added explain
- Added query stats
- Fixed CSS issues

## 0.1.0

- First major release
