module Api
  module V1
    module Admin
      class UsersController < BaseController
        # GET /api/v1/admin/users
        def index
          scope = User.includes(:role, :profile).order(created_at: :desc)

          if params[:q].present?
            like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.downcase)}%"
            scope = scope.where("LOWER(email) LIKE :q", q: like)
          end
          scope = scope.where(status: params[:status]) if params[:status].present?

          records, meta = paginate(scope)
          render_collection(records: records, serializer: UserSerializer, meta: meta)
        end

        # GET /api/v1/admin/users/:id
        def show
          user = User.includes(:profile, :wallets).find(params[:id])
          render json: {
            data: {
              user: UserSerializer.one(user),
              profile: ProfileSerializer.one(user.profile),
              wallets: WalletSerializer.many(user.wallets),
              restrictions: AccountRestrictionSerializer.many(user.account_restrictions.order(created_at: :desc)),
              active_sessions: user.sessions.active_now.count
            }
          }
        end

        # PATCH /api/v1/admin/users/:id
        def update
          user = User.find(params[:id])

          if user == current_user
            return render_error(code: "not_allowed", message: "You cannot change your own role or status.",
                                status: :unprocessable_content)
          end

          changes = {}
          if params[:role].present?
            role = Role.find_by!(name: params[:role])
            changes[:role] = { from: user.role.name, to: role.name }
            user.role = role
          end
          if params[:status].present?
            changes[:status] = { from: user.status, to: params[:status] }
            user.status = params[:status]
          end

          user.save!
          Audit::Record.call(actor: current_user, action: "admin.user_updated", auditable: user,
                             metadata: changes, request: request)
          render_resource(user, serializer: UserSerializer)
        end
      end
    end
  end
end
