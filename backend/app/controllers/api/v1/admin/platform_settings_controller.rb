module Api
  module V1
    module Admin
      class PlatformSettingsController < BaseController
        # GET /api/v1/admin/platform_settings
        def index
          scope = PlatformSetting.order(:category, :key)
          scope = scope.where(category: params[:category]) if params[:category].present?
          render_collection(records: scope, serializer: PlatformSettingSerializer)
        end

        # PATCH /api/v1/admin/platform_settings/:id
        def update
          setting = PlatformSetting.find(params[:id])

          if setting.editable == false
            return render_error(code: "not_editable", message: "This setting is not editable.",
                                status: :unprocessable_content)
          end

          setting.update!(setting_params)
          Audit::Record.call(actor: current_user, action: "admin.platform_setting_updated",
                             auditable: setting, metadata: { key: setting.key }, request: request)
          render_resource(setting, serializer: PlatformSettingSerializer)
        end

        private

        def setting_params
          params.require(:platform_setting).permit(:value, :description)
        end
      end
    end
  end
end
