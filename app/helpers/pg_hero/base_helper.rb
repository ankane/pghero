module PgHero
  module BaseHelper
    def pghero_size(bytes)
      number_to_human_size(bytes, precision: 3)
    end
  end
end
