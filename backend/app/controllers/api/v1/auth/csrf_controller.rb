module Api
  module V1
    module Auth
      # Issues a CSRF token bound to the current (possibly anonymous) session.
      # The SPA fetches this once per session and sends it back in the
      # X-CSRF-Token header on every state-changing request.
      class CsrfController < ApplicationController
        # GET /api/v1/auth/csrf
        def show
          render json: { data: { token: form_authenticity_token } }
        end
      end
    end
  end
end
