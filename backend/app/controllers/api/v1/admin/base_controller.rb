module Api
  module V1
    module Admin
      # Every admin endpoint requires an authenticated user whose role is
      # "admin". There is no public admin route and no client-side-only gate.
      class BaseController < ApplicationController
        before_action :authorize_admin!
      end
    end
  end
end
