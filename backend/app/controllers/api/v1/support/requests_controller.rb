module Api
  module V1
    module Support
      class RequestsController < ApplicationController
        # Support requests can be opened by guests or authenticated users.
        # A signed-in user's requests are linked to their account.

        # GET /api/v1/support/requests
        def index
          authenticate_user!
          return if performed?

          scope = current_user.support_requests.recent
          records, meta = paginate(scope)
          render_collection(records: records, serializer: SupportRequestSerializer, meta: meta)
        end

        # POST /api/v1/support/requests
        def create
          # `user: nil` for guests; contact details are expected inside `message`.
          support_request = ::SupportRequest.new(
            user: current_user,
            subject: params.require(:subject),
            message: params.require(:message),
            category: params.fetch(:category, :general)
          )

          if support_request.save
            render_resource(support_request, serializer: SupportRequestSerializer, status: :created)
          else
            render_error(code: "validation_failed", message: "Could not submit your request.",
                         status: :unprocessable_content,
                         details: support_request.errors.full_messages)
          end
        end
      end
    end
  end
end
