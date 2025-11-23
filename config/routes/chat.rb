# Chat and Role Play routes
resources :role_plays, only: [:index, :show] do
  resources :role_play_sessions, only: [:new, :create], path: "sessions"
end

resources :role_play_sessions, only: [:show], path: "chat/sessions"
