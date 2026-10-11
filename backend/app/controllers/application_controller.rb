class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection

  # State-changing requests must carry a valid CSRF token. The SPA obtains one
  # from GET /api/v1/auth/csrf and sends it in the X-CSRF-Token header.
  protect_from_forgery with: :exception

  SESSION_ID_KEY = :sid
  SESSION_TOKEN_KEY = :st

  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
  rescue_from ActiveRecord::RecordNotUnique, with: :handle_conflict
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_csrf
  rescue_from Authorization::NotAuthorized, with: :handle_not_authorized

  private

  # --- Authentication --------------------------------------------------------

  def current_user
    current_session&.user
  end

  def current_session
    return @current_session if defined?(@current_session)

    @current_session = resolve_current_session
  end

  def resolve_current_session
    sid = session[SESSION_ID_KEY]
    raw = session[SESSION_TOKEN_KEY]
    return nil if sid.blank? || raw.blank?

    record = Session.active_now.find_by(id: sid)
    return nil if record.nil?
    return nil unless ActiveSupport::SecurityUtils.secure_compare(record.token_digest, Session.digest(raw))
    return nil unless record.user.present?

    if idle_expired?(record)
      record.revoke!
      return nil
    end

    record.touch_last_seen!
    record
  end

  def idle_expired?(record)
    record.last_seen_at.present? && record.last_seen_at < Platform::SESSION_IDLE_TIMEOUT.ago
  end

  def authenticate_user!
    return if current_user.present?

    render_error(code: "unauthorized", message: "Authentication required.", status: :unauthorized)
  end

  def authenticate_active_user!
    authenticate_user!
    return if performed?
    return if current_user.active? || current_user.pending?

    render_error(code: "account_restricted", message: "This account cannot perform that action.", status: :forbidden)
  end

  def authorize!(permission)
    Authorization.authorize!(current_user, permission)
  end

  def authorize_admin!
    authenticate_user!
    return if performed?
    return if current_user.admin?

    render_error(code: "forbidden", message: "Administrator access required.", status: :forbidden)
  end

  # --- Session helpers -------------------------------------------------------

  def store_session_cookie(session_record, raw_token)
    reset_session
    session[SESSION_ID_KEY] = session_record.id
    session[SESSION_TOKEN_KEY] = raw_token
  end

  def clear_session_cookie
    reset_session
  end

  # --- Rendering -------------------------------------------------------------

  def render_error(code:, message:, status:, details: nil)
    render json: { error: { code: code, message: message, details: details }.compact }, status: status
  end

  def render_collection(records:, serializer:, meta: nil, **serializer_opts)
    payload = { data: serializer.many(records, **serializer_opts) }
    payload[:meta] = meta if meta
    render json: payload
  end

  def render_resource(record, serializer:, status: :ok, **serializer_opts)
    render json: { data: serializer.one(record, **serializer_opts) }, status: status
  end

  # --- Pagination ------------------------------------------------------------

  def paginate(scope, default_per: 20, max_per: 100)
    page = [params.fetch(:page, 1).to_i, 1].max
    per = params.fetch(:per_page, default_per).to_i
    per = default_per if per <= 0
    per = [per, max_per].min

    total = scope.count
    records = scope.limit(per).offset((page - 1) * per)

    meta = { page: page, per_page: per, total: total, total_pages: (total.to_f / per).ceil }
    [records, meta]
  end

  # --- Error handlers --------------------------------------------------------

  def handle_not_found
    render_error(code: "not_found", message: "The requested resource was not found.", status: :not_found)
  end

  def handle_record_invalid(exception)
    render_error(code: "validation_failed", message: "The request could not be processed.",
                 status: :unprocessable_content, details: exception.record.errors.full_messages)
  end

  def handle_conflict
    render_error(code: "conflict", message: "The resource already exists.", status: :conflict)
  end

  def handle_parameter_missing(exception)
    render_error(code: "bad_request", message: "Missing parameter: #{exception.param}",
                 status: :bad_request)
  end

  def handle_invalid_csrf
    render_error(code: "invalid_csrf_token", message: "Your session security token is invalid or missing.",
                 status: :unprocessable_content)
  end

  def handle_not_authorized(exception)
    render_error(code: "forbidden", message: "You do not have permission to perform this action.",
                 status: :forbidden, details: exception.permission)
  end
end
