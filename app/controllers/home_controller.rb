class HomeController < ApplicationController

  layout 'application'
  def index
    @html_title =  "Home"
    @html_title = @html_title 

    @map = Map.find(:all,
                             :order => "updated_at DESC",
                             :conditions => 'status = 4 OR status IN (2,3,4) ', 
                             :limit => 3)

    @featured_map = Map.find(:first,
                                     :order => "updated_at DESC", :conditions => 'status = 4 OR status IN (2,3,4) ', 
                                     :limit => 1)

    if logged_in?
      @my_maps = current_user.maps.find(:all, :order => "updated_at DESC", :limit => 3)
    end
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @map }
    end
  end





end
