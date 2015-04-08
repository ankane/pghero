## 1.0.0 [unreleased]

- More platforms!
- Added env vars for settings
- Added `replica?` method
- Added `ssl_used?` method

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
