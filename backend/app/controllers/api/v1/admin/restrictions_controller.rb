module Api
  module V1
    module Admin
      class RestrictionsController < BaseController
        SESSION_BLOCKING = %w[self_exclusion ban suspension cool_off].freeze

        # POST /api/v1/admin/restrictions
        def create
          user = User.find(params.require(:user_id))

          restriction = user.account_restrictions.create!(
            kind: params.require(:kind),
            status: :active,
            reason: params[:reason],
            starts_at: params[:starts_at].presence || Time.current,
            ends_at: params[:ends_at],
            imposed_by: current_user
          )

          user.sessions.active_now.find_each(&:revoke!) if SESSION_BLOCKING.include?(restriction.kind)

          Audit::Record.call(actor: current_user, action: "admin.restriction_imposed",
                             auditable: restriction,
                             metadata: { user_id: user.id, kind: restriction.kind }, request: request)

          render_resource(restriction, serializer: AccountRestrictionSerializer, status: :created)
        end

        # PATCH /api/v1/admin/restrictions/:id  (lift)
        def update
          restriction = AccountRestriction.find(params[:id])
          restriction.lift!(by: current_user)

          Audit::Record.call(actor: current_user, action: "admin.restriction_lifted",
                             auditable: restriction, request: request)

          render_resource(restriction, serializer: AccountRestrictionSerializer)
        end
      end
    end
  end
end
