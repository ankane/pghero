module PgHero
  module HomeHelper
    def pghero_pretty_ident(table, schema: nil)
      ident = table
      if schema && schema != "public"
        ident = "#{schema}.#{table}"
      end
      if /\A[a-z0-9_]+\z/.match?(ident)
        ident
      else
        @database.quote_ident(ident)
      end
    end

    def pghero_js_value(value)
      json_escape(value.to_json(root: false)).html_safe
    end

    def pghero_drop_idx_concurrently_explanation
      if @database.drop_idx_concurrently_supported?
        ret =  "<h2>Tip: Perform DROP INDEX operations using CONCURRENTLY</h2>"
        ret << "<ul><li>Add <code>disable_ddl_transaction!</code> to your migration</li>"
        ret << "<li>Add <code>algorithm: :concurrently</code> to each <code>remove_index</code></li></ul>"
        ret.html_safe
      end
    end

    def pghero_remove_index(query)
      if query[:columns]
        columns = query[:columns].map(&:to_sym)
        columns = columns.first if columns.size == 1
      end
      ret = String.new("remove_index #{query[:table].to_sym.inspect}")
      ret << ", name: #{(query[:name] || query[:index]).to_s.inspect}"
      ret << ", column: #{columns.inspect}" if columns
      ret << ", algorithm: :concurrently" if @database.drop_idx_concurrently_supported?
      ret
    end

    def pghero_formatted_vacuum_times(time)
      content_tag(:span, title: pghero_formatted_date_time(time)) do
        "#{time_ago_in_words(time, include_seconds: true).sub(/(over|about|almost) /, "").sub("less than", "<")} ago"
      end
    end

    def pghero_formatted_date_time(time)
      l time.in_time_zone(@time_zone), format: :long
    end
  end
end
