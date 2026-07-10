# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "performance#index"
  get "performance", to: "performance#index", as: :performance
end
