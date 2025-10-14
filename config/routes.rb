# frozen_string_literal: true

Sesame::Engine.routes.draw do
  post "sns", to: "sns#handle"
end
