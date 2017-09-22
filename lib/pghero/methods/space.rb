module PgHero
  module Methods
    module Space
      def database_size
        PgHero.pretty_size select_one("SELECT pg_database_size(current_database())")
      end

      def relation_sizes
        select_all_size <<-SQL
          SELECT
            n.nspname AS schema,
            c.relname AS relation,
            CASE WHEN c.relkind = 'r' THEN 'table' ELSE 'index' END AS type,
            pg_table_size(c.oid) AS size_bytes
          FROM
            pg_class c
          LEFT JOIN
            pg_namespace n ON n.oid = c.relnamespace
          WHERE
            n.nspname NOT IN ('pg_catalog', 'information_schema')
            AND n.nspname !~ '^pg_toast'
            AND c.relkind IN ('r', 'i')
          ORDER BY
            pg_table_size(c.oid) DESC,
            2 ASC
        SQL
      end

      def table_sizes
        select_all_size <<-SQL
          SELECT
            n.nspname AS schema,
            c.relname AS table,
            pg_total_relation_size(c.oid) AS size_bytes
          FROM
            pg_class c
          LEFT JOIN
            pg_namespace n ON n.oid = c.relnamespace
          WHERE
            n.nspname NOT IN ('pg_catalog', 'information_schema')
            AND n.nspname !~ '^pg_toast'
            AND c.relkind = 'r'
          ORDER BY
            pg_total_relation_size(c.oid) DESC,
            2 ASC
        SQL
      end

      def space_growth(days: 7, relation_sizes: nil)
        if space_stats_enabled?
          relation_sizes ||= self.relation_sizes
          sizes = Hash[ relation_sizes.map { |r| [[r[:schema], r[:relation]], r[:size_bytes]] } ]
          start_at = days.days.ago

          stats = select_all_stats <<-SQL
            WITH t AS (
              SELECT
                schema,
                relation,
                array_agg(size ORDER BY captured_at) AS sizes
              FROM
                pghero_space_stats
              WHERE
                database = #{quote(id)}
                AND captured_at >= #{quote(start_at)}
              GROUP BY
                1, 2
            )
            SELECT
              schema,
              relation,
              sizes[1] AS size_bytes
            FROM
              t
            ORDER BY
              1, 2
          SQL

          stats.each do |r|
            relation = [r[:schema], r[:relation]]
            if sizes[relation]
              r[:growth_bytes] = sizes[relation] - r[:size_bytes]
            end
            r.delete(:size_bytes)
          end
          stats
        else
          raise NotEnabled, "Space stats not enabled"
        end
      end

      def relation_space_stats(relation, schema: "public")
        if space_stats_enabled?
          relation_sizes ||= self.relation_sizes
          sizes = Hash[ relation_sizes.map { |r| [[r[:schema], r[:relation]], r[:size_bytes]] } ]
          start_at = 30.days.ago

          stats = select_all_stats <<-SQL
            SELECT
              captured_at,
              size AS size_bytes
            FROM
              pghero_space_stats
            WHERE
              database = #{quote(id)}
              AND captured_at >= #{quote(start_at)}
              AND schema = #{quote(schema)}
              AND relation = #{quote(relation)}
            ORDER BY
              1 ASC
          SQL

          stats << {
            captured_at: Time.now,
            size_bytes: sizes[[schema, relation]].to_i
          }
        else
          raise NotEnabled, "Space stats not enabled"
        end
      end

      def capture_space_stats
        now = Time.now
        columns = %w(database schema relation size captured_at)
        values = []
        relation_sizes.each do |rs|
          values << [id, rs[:schema], rs[:relation], rs[:size_bytes].to_i, now]
        end
        insert_stats("pghero_space_stats", columns, values) if values.any?
      end

      def space_stats_enabled?
        table_exists?("pghero_space_stats")
      end
    end
  end
end
