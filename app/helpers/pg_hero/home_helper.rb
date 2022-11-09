module PgHero
  module HomeHelper
    def pghero_humanize_duration_ms(millis)
      [[1000, "ms"], [60, "s"], [60, "m"], [24, "h"], [1000, "d"]].map do |count, name|
        if millis > 0
          millis, n = millis.divmod(count)
          "#{n.to_i}#{name}"
        end
      end.compact.reverse.join(" ")
    end

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
        "#{time_ago_in_words(time, include_seconds: true).sub(/(over|about|almost) /, "").sub("less than", "<")} ago"
      end
    end

    def pghero_formatted_date_time(time)
      l time.in_time_zone(@time_zone), format: :long
    end
  end
end
