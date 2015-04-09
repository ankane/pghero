PgHero::Engine.routes.draw do
  scope "(:database)", constraints: proc { |req| (PgHero.config["databases"].keys + [nil]).include?(req.params[:database]) } do
    get "indexes", to: "home#indexes"
    get "space", to: "home#space"
    get "queries", to: "home#queries"
    get "query_stats", to: "home#query_stats"
    get "system_stats", to: "home#system_stats"
    get "cpu_usage", to: "home#cpu_usage"
    get "connection_stats", to: "home#connection_stats"
    get "replication_lag_stats", to: "home#replication_lag_stats"
    get "explain", to: "home#explain"
    get "tune", to: "home#tune"
    get "connections", to: "home#connections"
    post "kill", to: "home#kill"
    post "kill_all", to: "home#kill_all"
    post "enable_query_stats", to: "home#enable_query_stats"
    post "explain", to: "home#explain"
    post "reset_query_stats", to: "home#reset_query_stats"
    root to: "home#index"
  end
end
