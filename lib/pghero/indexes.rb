module PgHero
  module Indexes
    def index_hit_rate
      select_all(<<-SQL
        SELECT
          (sum(idx_blks_hit)) / nullif(sum(idx_blks_hit + idx_blks_read), 0) AS rate
        FROM
          pg_statio_user_indexes
      SQL
      ).first["rate"].to_f
    end

    def index_caching
      select_all <<-SQL
        SELECT
          indexrelname AS index,
          relname AS table,
          CASE WHEN idx_blks_hit + idx_blks_read = 0 THEN
            0
          ELSE
            ROUND(1.0 * idx_blks_hit / (idx_blks_hit + idx_blks_read), 2)
          END AS hit_rate
        FROM
          pg_statio_user_indexes
        ORDER BY
          3 DESC, 1
      SQL
    end

    def index_usage
      select_all <<-SQL
        SELECT
          relname AS table,
          CASE idx_scan
            WHEN 0 THEN 'Insufficient data'
            ELSE (100 * idx_scan / (seq_scan + idx_scan))::text
          END percent_of_times_index_used,
          n_live_tup rows_in_table
        FROM
          pg_stat_user_tables
        ORDER BY
          n_live_tup DESC,
          relname ASC
       SQL
    end

    def missing_indexes
      select_all <<-SQL
        SELECT
          relname AS table,
          CASE idx_scan
            WHEN 0 THEN 'Insufficient data'
            ELSE (100 * idx_scan / (seq_scan + idx_scan))::text
          END percent_of_times_index_used,
          n_live_tup rows_in_table
        FROM
          pg_stat_user_tables
        WHERE
          idx_scan > 0
          AND (100 * idx_scan / (seq_scan + idx_scan)) < 95
          AND n_live_tup >= 10000
        ORDER BY
          n_live_tup DESC,
          relname ASC
       SQL
    end

    def unused_indexes
      select_all <<-SQL
        SELECT
          relname AS table,
          indexrelname AS index,
          pg_size_pretty(pg_relation_size(i.indexrelid)) AS index_size,
          idx_scan as index_scans
        FROM
          pg_stat_user_indexes ui
        INNER JOIN
          pg_index i ON ui.indexrelid = i.indexrelid
        WHERE
          NOT indisunique
          AND idx_scan < 50
        ORDER BY
          pg_relation_size(i.indexrelid) DESC,
          relname ASC
      SQL
    end

    def invalid_indexes
      select_all <<-SQL
        SELECT
          c.relname AS index
        FROM
          pg_catalog.pg_class c,
          pg_catalog.pg_namespace n,
          pg_catalog.pg_index i
        WHERE
          i.indisvalid = false
          AND i.indexrelid = c.oid
          AND c.relnamespace = n.oid
          AND n.nspname != 'pg_catalog'
          AND n.nspname != 'information_schema'
          AND n.nspname != 'pg_toast'
        ORDER BY
          c.relname
      SQL
    end

    # TODO parse array properly
    # http://stackoverflow.com/questions/2204058/list-columns-with-indexes-in-postgresql
    def indexes
      select_all( <<-SQL
        SELECT
          t.relname AS table,
          ix.relname AS name,
          regexp_replace(pg_get_indexdef(indexrelid), '^[^\\(]*\\((.*)\\)$', '\\1') AS columns,
          regexp_replace(pg_get_indexdef(indexrelid), '.* USING ([^ ]*) \\(.*', '\\1') AS using,
          indisunique AS unique,
          indisprimary AS primary,
          indisvalid AS valid,
          indexprs::text,
          indpred::text,
          pg_get_indexdef(indexrelid) AS definition
        FROM
          pg_index i
        INNER JOIN
          pg_class t ON t.oid = i.indrelid
        INNER JOIN
          pg_class ix ON ix.oid = i.indexrelid
        ORDER BY
          1, 2
      SQL
      ).map { |v| v["columns"] = v["columns"].sub(") WHERE (", " WHERE ").split(", "); v }
    end

    def duplicate_indexes
      indexes = []

      indexes_by_table = self.indexes.group_by { |i| i["table"] }
      indexes_by_table.values.flatten.select { |i| i["primary"] == "f" && i["unique"] == "f" && !i["indexprs"] && !i["indpred"] && i["valid"] == "t" }.each do |index|
        covering_index = indexes_by_table[index["table"]].find { |i| index_covers?(i["columns"], index["columns"]) && i["using"] == index["using"] && i["name"] != index["name"] && i["valid"] == "t" }
        if covering_index
          indexes << {"unneeded_index" => index, "covering_index" => covering_index}
        end
      end

      indexes.sort_by { |i| ui = i["unneeded_index"]; [ui["table"], ui["columns"]] }
    end

    def suggested_indexes_enabled?
      defined?(PgQuery) && query_stats_enabled?
    end

    # TODO clean this mess
    def suggested_indexes_by_query(options = {})
      best_indexes = {}

      if suggested_indexes_enabled?
        # get most time-consuming queries
        queries = options[:queries] || (options[:query_stats] || self.query_stats(historical: true, start_at: 24.hours.ago)).map { |qs| qs["query"] }

        # get best indexes for queries
        best_indexes = best_index_helper(queries)

        if best_indexes.any?
          existing_columns = Hash.new { |hash, key| hash[key] = Hash.new { |hash2, key2| hash2[key2] = [] } }
          indexes = self.indexes
          indexes.group_by { |g| g["using"] }.each do |group, inds|
            inds.each do |i|
              existing_columns[group][i["table"]] << i["columns"]
            end
          end
          indexes_by_table = indexes.group_by { |i| i["table"] }

          best_indexes.each do |query, best_index|
            if best_index[:found]
              index = best_index[:index]
              best_index[:table_indexes] = indexes_by_table[index[:table]].to_a
              covering_index = existing_columns[index[:using] || "btree"][index[:table]].find { |e| index_covers?(e, index[:columns]) }
              if covering_index
                best_index[:covering_index] = covering_index
                best_index[:explanation] = "Covered by index on (#{covering_index.join(", ")})"
              end
            end
          end
        end
      end

      best_indexes
    end

    def suggested_indexes(options = {})
      indexes = []

      (options[:suggested_indexes_by_query] || suggested_indexes_by_query(options)).select { |s, i| i[:found] && !i[:covering_index] }.group_by { |s, i| i[:index] }.each do |index, group|
        details = {}
        group.map(&:second).each do |g|
          details = details.except(:index).deep_merge(g)
        end
        indexes << index.merge(queries: group.map(&:first), details: details)
      end

      indexes.sort_by { |i| [i[:table], i[:columns]] }
    end

    def autoindex(options = {})
      suggested_indexes.each do |index|
        p index
        if options[:create]
          connection.execute("CREATE INDEX CONCURRENTLY ON #{quote_table_name(index[:table])} (#{index[:columns].map { |c| quote_table_name(c) }.join(",")})")
        end
      end
    end

    def autoindex_all(options = {})
      config["databases"].keys.each do |database|
        with(database) do
          puts "Autoindexing #{database}..."
          autoindex(options)
        end
      end
    end

    def best_index(statement, options = {})
      best_index_helper([statement])[statement]
    end
  end
end
