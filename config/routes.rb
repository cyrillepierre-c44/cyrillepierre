Rails.application.routes.draw do
  root to: "pages#home"

  get "expertise-operationnelle", to: "pages#operations",    as: :operations
  get "leadership-transformation", to: "pages#leadership",   as: :leadership
  get "tech-ia",                   to: "pages#tech",         as: :tech
  get "realisations",              to: "pages#realisations",  as: :realisations

  get "up" => "rails/health#show", as: :rails_health_check
end
