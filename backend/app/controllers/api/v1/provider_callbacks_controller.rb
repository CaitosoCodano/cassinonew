module Api
  module V1
    # Inbound, server-to-server callbacks from game providers.
    #
    # Authentication is by provider signature (verified by the adapter) rather
    # than by session, so CSRF protection is intentionally skipped. Every request
    # is still persisted to provider_events for the audit trail.
    class ProviderCallbacksController < ApplicationController
      skip_forgery_protection

      # POST /api/v1/provider_callbacks/:provider_slug
      def create
        provider = GameProvider.find_by!(slug: params[:provider_slug])
        raw_body = request.raw_post
        payload = parse_payload(raw_body)

        external_id = request.headers["X-Provider-Event-Id"].presence ||
                      payload["event_id"] || payload["id"]
        event_type = payload["type"].presence || payload["event_type"].presence || "unknown"

        result = Games::ProviderCallbackProcessor.call(
          provider: provider,
          raw_body: raw_body,
          headers: request.headers,
          payload: payload,
          external_id: external_id,
          event_type: event_type
        )

        if result.success?
          render json: { data: { status: result.status, event_id: result.provider_event&.id } },
                 status: :accepted
        else
          render_error(code: result.error.to_s, message: "Callback rejected.", status: :bad_request)
        end
      end

      private

      def parse_payload(raw_body)
        return {} if raw_body.blank?

        parsed = JSON.parse(raw_body)
        parsed.is_a?(Hash) ? parsed : {}
      rescue JSON::ParserError
        {}
      end
    end
  end
end
