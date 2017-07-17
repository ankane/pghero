module PgHero
  module BaseHelper
    def pghero_size(bytes)
      number_to_human_size(bytes, significant: false, precision: 0)
    end
  end
end
