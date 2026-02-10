# == Route Map
#
#                                     Prefix Verb   URI Pattern                                                                                       Controller#Action
#                                new_session GET    /session/new(.:format)                                                                            sessions#new
#                               edit_session GET    /session/edit(.:format)                                                                           sessions#edit
#                                    session GET    /session(.:format)                                                                                sessions#show
#                                            PATCH  /session(.:format)                                                                                sessions#update
#                                            PUT    /session(.:format)                                                                                sessions#update
#                                            DELETE /session(.:format)                                                                                sessions#destroy
#                                            POST   /session(.:format)                                                                                sessions#create
#                                  passwords GET    /passwords(.:format)                                                                              passwords#index
#                                            POST   /passwords(.:format)                                                                              passwords#create
#                               new_password GET    /passwords/new(.:format)                                                                          passwords#new
#                              edit_password GET    /passwords/:token/edit(.:format)                                                                  passwords#edit
#                                   password GET    /passwords/:token(.:format)                                                                       passwords#show
#                                            PATCH  /passwords/:token(.:format)                                                                       passwords#update
#                                            PUT    /passwords/:token(.:format)                                                                       passwords#update
#                                            DELETE /passwords/:token(.:format)                                                                       passwords#destroy
#                           new_registration GET    /registration/new(.:format)                                                                       registrations#new
#                               registration POST   /registration(.:format)                                                                           registrations#create
#                   update_password_settings PATCH  /settings/update_password(.:format)                                                               settings#update_password
#                                   settings GET    /settings(.:format)                                                                               settings#show
#                                            PATCH  /settings(.:format)                                                                               settings#update
#                                            PUT    /settings(.:format)                                                                               settings#update
#                                       root GET    /                                                                                                 dashboard#index
#                            set_default_gym POST   /gyms/:id/set_default(.:format)                                                                   gyms#set_default
#                               gym_machines GET    /gyms/:gym_id/machines(.:format)                                                                  machines#index
#                                            POST   /gyms/:gym_id/machines(.:format)                                                                  machines#create
#                            new_gym_machine GET    /gyms/:gym_id/machines/new(.:format)                                                              machines#new
#                           edit_gym_machine GET    /gyms/:gym_id/machines/:id/edit(.:format)                                                         machines#edit
#                                gym_machine GET    /gyms/:gym_id/machines/:id(.:format)                                                              machines#show
#                                            PATCH  /gyms/:gym_id/machines/:id(.:format)                                                              machines#update
#                                            PUT    /gyms/:gym_id/machines/:id(.:format)                                                              machines#update
#                                            DELETE /gyms/:gym_id/machines/:id(.:format)                                                              machines#destroy
#                                       gyms GET    /gyms(.:format)                                                                                   gyms#index
#                                            POST   /gyms(.:format)                                                                                   gyms#create
#                                    new_gym GET    /gyms/new(.:format)                                                                               gyms#new
#                                   edit_gym GET    /gyms/:id/edit(.:format)                                                                          gyms#edit
#                                        gym GET    /gyms/:id(.:format)                                                                               gyms#show
#                                            PATCH  /gyms/:id(.:format)                                                                               gyms#update
#                                            PUT    /gyms/:id(.:format)                                                                               gyms#update
#                                            DELETE /gyms/:id(.:format)                                                                               gyms#destroy
#                           history_exercise GET    /exercises/:id/history(.:format)                                                                  exercises#history
#                                  exercises GET    /exercises(.:format)                                                                              exercises#index
#                                            POST   /exercises(.:format)                                                                              exercises#create
#                               new_exercise GET    /exercises/new(.:format)                                                                          exercises#new
#                              edit_exercise GET    /exercises/:id/edit(.:format)                                                                     exercises#edit
#                                   exercise GET    /exercises/:id(.:format)                                                                          exercises#show
#                                            PATCH  /exercises/:id(.:format)                                                                          exercises#update
#                                            PUT    /exercises/:id(.:format)                                                                          exercises#update
#                                            DELETE /exercises/:id(.:format)                                                                          exercises#destroy
#                             finish_workout PATCH  /workouts/:id/finish(.:format)                                                                    workouts#finish
#                           continue_workout PATCH  /workouts/:id/continue(.:format)                                                                  workouts#continue_workout
#                       add_exercise_workout GET    /workouts/:id/add_exercise(.:format)                                                              workouts#add_exercise
#                                            POST   /workouts/:id/add_exercise(.:format)                                                              workouts#add_exercise
#                               copy_workout POST   /workouts/:id/copy(.:format)                                                                      workouts#copy
#                     reorder_blocks_workout PATCH  /workouts/:id/reorder_blocks(.:format)                                                            workouts#reorder_blocks
#     workout_workout_exercise_exercise_sets POST   /workouts/:workout_id/workout_exercises/:workout_exercise_id/exercise_sets(.:format)              exercise_sets#create
# edit_workout_workout_exercise_exercise_set GET    /workouts/:workout_id/workout_exercises/:workout_exercise_id/exercise_sets/:id/edit(.:format)     exercise_sets#edit
#      workout_workout_exercise_exercise_set PATCH  /workouts/:workout_id/workout_exercises/:workout_exercise_id/exercise_sets/:id(.:format)          exercise_sets#update
#                                            PUT    /workouts/:workout_id/workout_exercises/:workout_exercise_id/exercise_sets/:id(.:format)          exercise_sets#update
#                                            DELETE /workouts/:workout_id/workout_exercises/:workout_exercise_id/exercise_sets/:id(.:format)          exercise_sets#destroy
#     move_to_block_workout_workout_exercise PATCH  /workouts/:workout_id/workout_exercises/:id/move_to_block(.:format)                               workout_exercises#move_to_block
#              edit_workout_workout_exercise GET    /workouts/:workout_id/workout_exercises/:id/edit(.:format)                                        workout_exercises#edit
#                   workout_workout_exercise GET    /workouts/:workout_id/workout_exercises/:id(.:format)                                             workout_exercises#show
#                                            PATCH  /workouts/:workout_id/workout_exercises/:id(.:format)                                             workout_exercises#update
#                                            PUT    /workouts/:workout_id/workout_exercises/:id(.:format)                                             workout_exercises#update
#                                            DELETE /workouts/:workout_id/workout_exercises/:id(.:format)                                             workout_exercises#destroy
#                                   workouts GET    /workouts(.:format)                                                                               workouts#index
#                                            POST   /workouts(.:format)                                                                               workouts#create
#                                new_workout GET    /workouts/new(.:format)                                                                           workouts#new
#                               edit_workout GET    /workouts/:id/edit(.:format)                                                                      workouts#edit
#                                    workout GET    /workouts/:id(.:format)                                                                           workouts#show
#                                            PATCH  /workouts/:id(.:format)                                                                           workouts#update
#                                            PUT    /workouts/:id(.:format)                                                                           workouts#update
#                                            DELETE /workouts/:id(.:format)                                                                           workouts#destroy
#                         rails_health_check GET    /up(.:format)                                                                                     rails/health#show
#                               pwa_manifest GET    /manifest(.:format)                                                                               rails/pwa#manifest
#                         pwa_service_worker GET    /service-worker(.:format)                                                                         rails/pwa#service_worker
#           turbo_recede_historical_location GET    /recede_historical_location(.:format)                                                             turbo/native/navigation#recede
#           turbo_resume_historical_location GET    /resume_historical_location(.:format)                                                             turbo/native/navigation#resume
#          turbo_refresh_historical_location GET    /refresh_historical_location(.:format)                                                            turbo/native/navigation#refresh
#              rails_postmark_inbound_emails POST   /rails/action_mailbox/postmark/inbound_emails(.:format)                                           action_mailbox/ingresses/postmark/inbound_emails#create
#                 rails_relay_inbound_emails POST   /rails/action_mailbox/relay/inbound_emails(.:format)                                              action_mailbox/ingresses/relay/inbound_emails#create
#              rails_sendgrid_inbound_emails POST   /rails/action_mailbox/sendgrid/inbound_emails(.:format)                                           action_mailbox/ingresses/sendgrid/inbound_emails#create
#        rails_mandrill_inbound_health_check GET    /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#health_check
#              rails_mandrill_inbound_emails POST   /rails/action_mailbox/mandrill/inbound_emails(.:format)                                           action_mailbox/ingresses/mandrill/inbound_emails#create
#               rails_mailgun_inbound_emails POST   /rails/action_mailbox/mailgun/inbound_emails/mime(.:format)                                       action_mailbox/ingresses/mailgun/inbound_emails#create
#             rails_conductor_inbound_emails GET    /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#index
#                                            POST   /rails/conductor/action_mailbox/inbound_emails(.:format)                                          rails/conductor/action_mailbox/inbound_emails#create
#          new_rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/new(.:format)                                      rails/conductor/action_mailbox/inbound_emails#new
#              rails_conductor_inbound_email GET    /rails/conductor/action_mailbox/inbound_emails/:id(.:format)                                      rails/conductor/action_mailbox/inbound_emails#show
#   new_rails_conductor_inbound_email_source GET    /rails/conductor/action_mailbox/inbound_emails/sources/new(.:format)                              rails/conductor/action_mailbox/inbound_emails/sources#new
#      rails_conductor_inbound_email_sources POST   /rails/conductor/action_mailbox/inbound_emails/sources(.:format)                                  rails/conductor/action_mailbox/inbound_emails/sources#create
#      rails_conductor_inbound_email_reroute POST   /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format)                               rails/conductor/action_mailbox/reroutes#create
#   rails_conductor_inbound_email_incinerate POST   /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format)                            rails/conductor/action_mailbox/incinerates#create
#                         rails_service_blob GET    /rails/active_storage/blobs/redirect/:signed_id/*filename(.:format)                               active_storage/blobs/redirect#show
#                   rails_service_blob_proxy GET    /rails/active_storage/blobs/proxy/:signed_id/*filename(.:format)                                  active_storage/blobs/proxy#show
#                                            GET    /rails/active_storage/blobs/:signed_id/*filename(.:format)                                        active_storage/blobs/redirect#show
#                  rails_blob_representation GET    /rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations/redirect#show
#            rails_blob_representation_proxy GET    /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)    active_storage/representations/proxy#show
#                                            GET    /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format)          active_storage/representations/redirect#show
#                         rails_disk_service GET    /rails/active_storage/disk/:encoded_key/*filename(.:format)                                       active_storage/disk#show
#                  update_rails_disk_service PUT    /rails/active_storage/disk/:encoded_token(.:format)                                               active_storage/disk#update
#                       rails_direct_uploads POST   /rails/active_storage/direct_uploads(.:format)                                                    active_storage/direct_uploads#create

Rails.application.routes.draw do
  # Authentication
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  # Settings
  resource :settings, only: %i[show update] do
    patch :update_password, on: :member
    get :export_data, on: :member
    get :export_csv, on: :member
    get :export_prs, on: :member
  end

  # Dashboard
  root 'dashboard#index'

  # Gyms & Machines
  resources :gyms do
    member do
      post :set_default
    end
    resources :machines do
      member do
        delete :delete_photo
      end
    end
  end

  # Exercise Library
  resources :exercises do
    member do
      get :history
    end
  end

  # Body Metrics (weight and measurements tracking)
  resources :body_metrics, except: [ :show ]

  # Workout Templates
  resources :workout_templates do
    member do
      post :start_workout
      patch :reorder_blocks
    end
    resources :exercises, controller: 'template_exercises', as: 'template_exercises'
    resources :blocks, controller: 'template_blocks', as: 'template_blocks', only: [ :destroy ]
  end
  post 'workouts/:workout_id/save_as_template', to: 'workout_templates#create_from_workout', as: :save_workout_as_template

  # Workouts
  resources :workouts do
    member do
      patch :finish
      patch :continue, to: 'workouts#continue_workout'
      get :add_exercise
      post :add_exercise
      post :copy
      patch :reorder_blocks
      get :share_text
    end
    resources :workout_exercises, only: [ :show, :edit, :update, :destroy ] do
      resources :exercise_sets, only: [ :create, :edit, :update, :destroy ]
      member do
        patch :move_to_block
        post :generate_warmups
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # PWA
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker
end
