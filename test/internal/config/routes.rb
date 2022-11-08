Rails.application.routes.draw do
  mount PgHero::Engine, at: "/"
end
