module Api
  module V1
    module Admin
      class FeatureFlagsController < BaseController
        # GET /api/v1/admin/feature_flags
        def index
          render_collection(records: FeatureFlag.order(:key), serializer: FeatureFlagSerializer)
        end

        # POST /api/v1/admin/feature_flags
        def create
          flag = FeatureFlag.new(flag_params)
          flag.save!
          Audit::Record.call(actor: current_user, action: "admin.feature_flag_created",
                             auditable: flag, metadata: { key: flag.key }, request: request)
          render_resource(flag, serializer: FeatureFlagSerializer, status: :created)
        end

        # PATCH /api/v1/admin/feature_flags/:id
        def update
          flag = FeatureFlag.find(params[:id])
          flag.update!(flag_params)
          Audit::Record.call(actor: current_user, action: "admin.feature_flag_updated",
                             auditable: flag,
                             metadata: { key: flag.key, enabled: flag.enabled,
                                         rollout_percentage: flag.rollout_percentage },
                             request: request)
          render_resource(flag, serializer: FeatureFlagSerializer)
        end

        private

        def flag_params
          params.require(:feature_flag).permit(:key, :enabled, :description, :rollout_percentage, metadata: {})
        end
      end
    end
  end
end
