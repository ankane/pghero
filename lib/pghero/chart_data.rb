module PgHero
  class ChartData
    def initialize(input)
      @input = input
    end

    def series(limit)
      sorted = @input.sort { |a, b| b[1] <=> a[1] }
      result = sorted.first(limit-1)
      result << ['Others', sorted[limit-1..-1].map(&:last).inject(:+)] if limit < sorted.length
    end
  end
end
