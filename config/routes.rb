Rails.application.routes.draw do
  root to: "pages#home"

  get "expertise-operationnelle", to: "pages#operations",    as: :operations
  get "leadership-transformation", to: "pages#leadership",   as: :leadership
  get "tech-ia",                   to: "pages#tech",         as: :tech
  get "realisations",              to: "pages#realisations",  as: :realisations

  get  "contact",           to: "contacts#new",       as: :contact
  post "contact",           to: "contacts#create"
  post "contact/chat",      to: "contacts#chat",      as: :contact_chat
  post "contact/summarize", to: "contacts#summarize", as: :contact_summarize

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
