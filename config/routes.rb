# frozen_string_literal: true

Spree::Core::Engine.routes.draw do
  namespace :admin do
    resource :cicerone, only: %i[show update], controller: "cicerone" do
      post :retrain
    end
  end

  post "/cicerone/track", to: "cicerone_tracks#create", as: :cicerone_track
end
