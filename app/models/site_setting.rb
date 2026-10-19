# == Schema Information
#
# Table name: site_settings
#
#  id                    :integer          not null, primary key
#  registrations_enabled :boolean          default(TRUE), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
class SiteSetting < ApplicationRecord
  validates :registrations_enabled, inclusion: { in: [ true, false ] }

  def self.current
    find_or_create_by!(id: 1)
  end
end
