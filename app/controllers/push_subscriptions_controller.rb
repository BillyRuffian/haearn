class PushSubscriptionsController < ApplicationController
  def create
    subscription = subscription_params

    record = Current.user.push_subscriptions.find_or_initialize_by(endpoint: subscription[:endpoint])
    record.assign_attributes(
      p256dh_key: subscription.dig(:keys, :p256dh),
      auth_key: subscription.dig(:keys, :auth),
      expiration_time: subscription[:expiration_time],
      user_agent: request.user_agent
    )

    if record.save
      render json: { ok: true, id: record.id }
    else
      render json: { ok: false, errors: record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    endpoint = params[:endpoint].to_s
    return head :unprocessable_entity if endpoint.blank?

    Current.user.push_subscriptions.where(endpoint: endpoint).delete_all
    head :ok
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, :expiration_time, keys: [ :p256dh, :auth ])
  end
end
