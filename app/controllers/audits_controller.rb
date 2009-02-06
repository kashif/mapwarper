class AuditsController < ApplicationController
  layout "application",  :except => [:for_map]

  def show
    @audit  = Activity.find(params[:id])
  end

  def index
    @audits = Activity.paginate(:page => params[:page],
    :per_page => 20,
    :order => "created_at DESC")
    @title = "Recent Activity For Everything"
    @linktomap = "yes please"
    render :action => 'index'
  end



  def for_user
    @user = User.find(params[:id])

    @audits = Activity.paginate(:page => params[:page],
    :per_page => 20,
    :order => "created_at DESC",
    :conditions => ['user_id = ?', params[:id] ])
    @title = "Recent Activity for User " +@user.login.capitalize
    render :action => 'index'
  end

  def for_map
    @current_tab = :activity
    @html_title = "Activity"
    
    @map = Map.find(params[:id])

    @audits = Activity.paginate(:page => params[:page],
    :per_page => 20,
    :order => "created_at DESC",
    :conditions => ['auditable_type = ? AND auditable_id = ?',
    'Map', @map.id])
    @title = "Recent Activity for Map "+params[:id].to_s
    render :action => 'index', :layout => 'mapdetail'
  end

  def for_map_model
    @audits = Activity.paginate(:page => params[:page],
    :per_page => 20,
    :conditions => ['auditable_type = ?', 'Map'],
    :order => 'created_at DESC')

    @title = "Recent Activity for All Maps"
    render :action => 'index'
  end



end

