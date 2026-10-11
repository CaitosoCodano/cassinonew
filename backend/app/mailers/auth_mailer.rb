class AuthMailer < ApplicationMailer
  default from: -> { "#{Platform::BRAND_NAME} <no-reply@example.invalid>" }

  def verify_email(user, raw_token)
    @user = user
    @brand = Platform::BRAND_NAME
    @verify_url = "#{Platform::WEB_CLIENT_URL}/verify-email?token=#{raw_token}"

    mail(to: user.email, subject: "Verify your #{@brand} account")
  end

  def reset_password(user, raw_token)
    @user = user
    @brand = Platform::BRAND_NAME
    @reset_url = "#{Platform::WEB_CLIENT_URL}/reset-password?token=#{raw_token}"
    @expires_in_minutes = (PasswordResetToken::EXPIRY / 60).to_i

    mail(to: user.email, subject: "Reset your #{@brand} password")
  end
end
