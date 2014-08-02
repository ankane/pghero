require 'ostruct'

module PgHero
  class SpaceUsage
    def initialize(total_bytes, relation_sizes)
      @total_bytes = total_bytes.to_i
      @relation_sizes = relation_sizes
    end

    def total
      @total_bytes
    end

    def relations
      @relation_sizes.map do |rs|
        size = rs['size'].to_i
        OpenStruct.new name: rs['name'],
                       type: rs['type'],
                       size: size,
                       size_percentage: (size / total.to_f) * 100
      end
    end
  end
end
