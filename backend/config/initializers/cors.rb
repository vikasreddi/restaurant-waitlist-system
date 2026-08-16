# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Dev-only: allows the frontend dev server (Docker Compose service or local Vite) to call this API.
# FRONTEND_URL is set in docker-compose.yml; defaults to the default Vite dev port for non-Docker use.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_URL") { "http://localhost:5173" }

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
