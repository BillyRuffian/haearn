# == Schema Information
#
# Table name: app_presences
#
#  id         :integer          not null, primary key
#  expires_at :datetime         not null
#  sequence   :integer          default(0), not null
#  client_id  :string           not null
#  session_id :integer          not null
#
# Indexes
#
#  index_app_presences_on_expires_at                (expires_at)
#  index_app_presences_on_session_id                (session_id)
#  index_app_presences_on_session_id_and_client_id  (session_id,client_id) UNIQUE
#
# Foreign Keys
#
#  session_id  (session_id => sessions.id)
#
class AppPresence < ApplicationRecord
  LEASE = 45.seconds

  belongs_to :session

  def self.visible_for?(user)
    joins(:session).where(sessions: { user_id: user.id }).where('expires_at > ?', Time.current).exists?
  end

  def self.report!(session:, client_id:, sequence:, visible:)
    presence = find_or_create_by!(session: session, client_id: client_id) do |record|
      record.expires_at = Time.current
    end
    # A late heartbeat must not undo a newer hidden/pagehide report.
    where(id: presence.id).where('sequence < ?', sequence).update_all(
      sequence: sequence, expires_at: visible ? LEASE.from_now : Time.current)
  end
end
