# Serves the built single-page application in production.
class StaticController < ApplicationController
  skip_forgery_protection only: :index

  def index
    index_path = Rails.root.join("public", "index.html")

    if index_path.exist?
      send_file index_path, type: "text/html", disposition: "inline"
    else
      render plain: "The web client has not been built. Run the frontend build and copy its " \
                    "output to backend/public (see README).",
             status: :service_unavailable
    end
  end
end
