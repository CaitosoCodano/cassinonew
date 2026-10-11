class ProfileSerializer < ApplicationSerializer
  def as_json
    return nil if record.nil?

    {
      display_name: record.display_name,
      first_name: record.first_name,
      last_name: record.last_name,
      date_of_birth: record.date_of_birth,
      country_code: record.country_code,
      phone: record.phone,
      locale: record.locale,
      marketing_opt_in: record.marketing_opt_in,
      identity_verification_status: record.identity_verification_status,
      identity_reviewed_at: record.identity_reviewed_at
    }
  end
end
