Rails.application.routes.draw do
  devise_for :users, skip: [:registrations]
  root to: "pages#home"

  get "expertise-operationnelle", to: "pages#operations",    as: :operations
  get "leadership-transformation", to: "pages#leadership",   as: :leadership
  get "tech-ia",                   to: "pages#tech",         as: :tech
  get "realisations",              to: "pages#realisations",  as: :realisations
  get "cv",                        to: "pages#cv",            as: :cv

  get  "contact",           to: "contacts#new",       as: :contact
  post "contact",           to: "contacts#create"
  post "contact/chat",           to: "contacts#chat",           as: :contact_chat
  post "contact/summarize",      to: "contacts#summarize",      as: :contact_summarize
  post "contact/infer_company",  to: "contacts#infer_company",  as: :contact_infer_company

  resources :actus, only: [:index, :show]

  namespace :studio do
    resources :generations do
      member do
        patch :regenerate
        patch :publish
        patch :unpublish
        patch :generate_visual
      end
    end
  end

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
