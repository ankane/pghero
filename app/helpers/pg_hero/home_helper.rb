module PgHero
  module HomeHelper
    def pghero_pretty_ident(table, schema: nil)
      ident = table
      if schema && schema != "public"
        ident = "#{schema}.#{table}"
      end
      if ident =~ /\A[a-z0-9_]+\z/
        ident
      else
        @database.quote_ident(ident)
      end
    end

    def pghero_js_var(name, value)
      "var #{name} = #{json_escape(value.to_json(root: false))};".html_safe
    end

    def pghero_remove_index(query)
      if query[:columns]
        columns = query[:columns].map(&:to_sym)
        columns = columns.first if columns.size == 1
      end
      ret = String.new("remove_index #{query[:table].to_sym.inspect}")
      ret << ", name: #{(query[:name] || query[:index]).to_s.inspect}"
      ret << ", column: #{columns.inspect}" if columns
      ret
    end

    def pghero_formatted_vacuum_times(time)
      content_tag(:span, title: pghero_formatted_date_time(time)) do
        "#{time_ago_in_words(time.in_time_zone(@time_zone))} ago"
      end
    end

    def pghero_formatted_date_time(time)
      l time.in_time_zone(@time_zone), format: :long
    end
  end
end
