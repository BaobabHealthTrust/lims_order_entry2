Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'patient#barcode'
  get 'patient/confirm'
  get 'patient/barcode'
  get 'patient/new_lab_results'
  get 'patient/test_types'
  post 'patient/new_order'
  get 'patient/print_tracking_number'
  get 'patient/show'
  get 'user/logout'
  get 'user/ext'
  get 'user/login'
  post 'user/login'
  post 'user/do_login'
  get  'patient/captureDispatcher'
  post 'patient/postDispatcher'
  get '/load_orders' => 'patient#load_orders'
  post 'patient/dispatchingSummary'
  get 'patient/dispatchingSummary'
  post '/load_orders' => 'patient#load_orders'
  get  '/patient/enter_test_result' => 'patient#enter_test_result'
  

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
