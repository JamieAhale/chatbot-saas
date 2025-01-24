Rails.application.routes.draw do

  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'

  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }

  devise_scope :user do
    get 'account', to: 'users/registrations#show', as: :user_show
    get 'account/edit', to: 'users/registrations#edit', as: :user_edit
  end

  root 'assistants#chat'

  # Define a named route for the chat action
  # get 'assistants/chat', to: 'assistants#chat', as: :chat

  # Define a named route for the documents action
  get 'assistants/documents', to: 'assistants#documents', as: :documents

  # Define a named route for the upload_document action
  post 'assistants/upload_document', to: 'assistants#upload_document', as: :upload_document

  # Define a named route for the delete_document action
  post 'assistants/delete_document', to: 'assistants#delete_document', as: :delete_document

  # Define a named route for the view_document action
  get 'assistants/:file_id/view_document', to: 'assistants#view_document', as: 'view_document'

  # Define a named route for the check_status action
  get 'assistants/:file_id/check_status', to: 'assistants#check_status', as: 'check_status'

  # Define a named route for the assistant settings action
  get 'assistants/settings', to: 'assistants#settings', as: :assistant_settings

  # Define a named route for the update_instructions action
  patch 'assistants/update_instructions', to: 'assistants#update_instructions', as: :update_instructions

  # Define a named route for the conversations action
  get 'assistants/conversations', to: 'assistants#conversations', as: :conversations

  # Define a named route for the show_conversation action
  get 'assistants/conversations/:id', to: 'assistants#show_conversation', as: :show_conversation

  # Define a named route for the destroy_conversation action
  delete 'assistants/conversations/:id', to: 'assistants#destroy_conversation', as: :conversation

  # Define a named route for the conversations_for_review action
  get 'assistants/conversations_for_review', to: 'assistants#conversations_for_review', as: :conversations_for_review

  # Define a named route for the show_conversation_for_review action
  get 'assistants/conversations_for_review/:id', to: 'assistants#show_conversation_for_review', as: :show_conversation_for_review

  # Define a named route for the mark_resolved_conversation action
  patch 'assistants/conversations/:id/mark_resolved', to: 'assistants#mark_resolved', as: :mark_resolved_conversation

  # Define a named route for the dismiss_conversation action
  patch 'assistants/conversations/:id/dismiss', to: 'assistants#dismiss', as: :dismiss_conversation

  # Define a named route for the delete_selected_conversations action
  delete 'assistants/delete_selected_conversations', to: 'assistants#delete_selected_conversations', as: :delete_selected_conversations

  # Define a named route for batch mark resolved action
  patch 'assistants/mark_resolved_conversations', to: 'assistants#mark_resolved_conversations', as: :mark_resolved_conversations

  # Define a named route for batch dismiss action
  patch 'assistants/dismiss_conversations', to: 'assistants#dismiss_conversations', as: :dismiss_conversations

  patch 'assistants/flag_selected_conversations', to: 'assistants#flag_selected_conversations', as: :flag_selected_conversations

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")

  resources :conversations do
    member do
      patch 'flag_for_review', to: 'assistants#flag_for_review'
      post 'generate_summary', to: 'assistants#generate_summary'
    end
  end

  namespace :api do
    namespace :v1 do
      post 'chat', to: 'chat#create'
      get 'chat/:id/last_messages', to: 'chat#last_messages'
    end
  end

  post 'initiate_scrape', to: 'assistants#initiate_scrape', as: 'initiate_scrape'

  get 'widget_generator', to: 'assistants#widget_generator'
  post 'generate_widget_code', to: 'assistants#generate_widget_code'

  post 'assistants/refresh_website_content', to: 'assistants#refresh_website_content', as: :refresh_website_content_assistants

  post '/stripe/webhook', to: 'stripe#webhook'

  resource :subscription, only: [:edit, :update, :destroy]

end
