Rails.application.routes.draw do
  # Define a named route for the chat action
  get 'assistants/chat', to: 'assistants#chat', as: :chat

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

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root 'assistants#chat'
end
