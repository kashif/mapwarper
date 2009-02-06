ActionController::Routing::Routes.draw do |map|

  map.root :controller => "home", :action => "index"
  
#  NOTE: these activity routes are for optional audited actions. we've turned this off by default.
  map.user_activity '/users/:id/activity', :controller => 'audits', :action => 'for_user'
  map.formatted_user_activity '/users/:id/activity.:format', :controller => 'audits', :action => 'for_user'
  map.maps_activity '/maps/activity', :controller => 'audits', :action => 'for_map_model'
  map.formatted_maps_activity  '/maps/activity.:format', :controller => 'audits', :action => 'for_map_model'
  map.map_activity '/maps/:id/activity', :controller => 'audits', :action => 'for_map'
  map.formatted_map_activity '/maps/:id/activity.:format', :controller => 'audits', :action => 'for_map'
  map.activity '/activity', :controller => 'audits'
  map.formatted_activity '/activity.:format', :controller => 'audits'
  map.activity_details '/activity/:id', :controller => 'audits',:action => 'show'
  map.connect '/maps/activity', :controller => 'audits', :action => 'for_map_model'

  map.connect '/gcps/:id', :controller => 'gcp', :action=> 'show'
  map.connect '/gcps/show/:id', :controller=> 'gcp', :action=>'show'

  map.my_maps '/users/:user_id/maps', :controller => 'my_maps', :action => 'list'
  #map.connect '/users/:user_id/maps/new', :controller => 'my_maps', :action => 'new'
  #map.connect '/users/:user_id/maps/:id', :controller => 'my_maps', :action => 'show'
  map.add_my_map '/users/:user_id/maps/create/:map_id', :controller => 'my_maps', :action => 'create', :conditions => { :method => :post }
  map.destroy_my_map '/users/:user_id/maps/destroy/:map_id', :controller => 'my_maps', :action => 'destroy', :conditions => { :method => :post}



  map.login '/login', :controller => 'sessions', :action => 'new'
  map.logout '/logout', :controller => 'sessions', :action => 'destroy'
  map.signup '/signup', :controller => 'users', :action => 'new'
  map.resend_activation '/resend_activation', :controller => 'users', :action => 'resend_activation'
  map.activate '/activate/:id', :controller => 'user_accounts', :action => 'show'
  map.change_password '/change_password',   :controller => 'user_accounts', :action => 'edit'
  map.forgot_password '/forgot_password',   :controller => 'passwords', :action => 'new'
  map.reset_password '/reset_password/:id', :controller => 'passwords', :action => 'edit'
# map.resources :users, :has_many => :user_maps,  
  map.force_activate '/force_activate/:id', :controller => 'users', :action => 'force_activate', :conditions =>{:method => :put}
  map.resources :users, :member => {:enable => :put } do |users| 
  users.resource :user_account
  users.resources :roles
  end

  map.resource :session
  map.resource :password
  #end authentication route stuff

  #nicer paths for often used map paths
  map.warp_map '/maps/warp/:id', :controller => 'maps', :action => 'warp'
  map.clip_map '/maps/crop/:id', :controller => 'maps', :action => 'clip'
  map.align_map '/maps/align/:id', :controller => 'maps', :action => 'align'
  map.warped_map '/maps/preview/:id', :controller => 'maps', :action => 'warped'
  map.map_status '/maps/status/:id', :controller => 'maps', :action => 'status'
  map.export_map '/maps/export/:id', :controller => 'maps', :action => 'export'
  map.resources :maps

  


  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
 #map.connect '', :controller => "maps"
  map.connect '', :controller => "home"
end
