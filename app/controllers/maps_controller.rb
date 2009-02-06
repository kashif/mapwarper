class MapsController < ApplicationController
  # GET /maps
  # GET /maps.xml
  layout 'mapdetail', :except => [:index, :new]
  before_filter :login_required, :only => [:destroy]
  #before_filter :login_required, :only => [:warp, :rectify, :clip, :align,
  #:warp_align, :mask_map, :delete_mask, :save_mask, :save_mask_and_warp ]
  before_filter :check_administrator_role, :only => [:publish, :destroy]
  before_filter :find_map_if_available,
    :except => [:show, :index, :wms, :warp_aligned, :status, :new, :create, :update, :edit]

  before_filter :check_link_back, :only => [:show, :warp, :clip, :align, :warped, :activity]
  before_filter :check_if_map_is_editable, :only => [:edit, :update, :destroy]
  helper :sort
  include SortHelper

  def index
     
    sort_init 'updated_at'
    sort_update
    @show_warped = params[:show_warped]
    request.query_string.length > 0 ?  qstring = "?" + request.query_string : qstring = ""
          
    set_session_link_back url_for(:controller=> 'maps', :action => 'index',:skip_relative_url_root => false, :only_path => false )+ qstring

    @query = params[:query]

    @field = %w(title description status publisher authors).detect{|f| f== (params[:field])}
    @field = "title" if @field.nil?

    if @query && @query.strip.length > 0 && @field
      if @show_warped == "1"
        conditions =  ["upper(#{@field} )  LIKE ?  AND status = 4 ", '%'+@query.upcase+'%' ]
      else
        conditions =  ["upper(#{@field} ) LIKE ? ", '%'+@query.upcase+'%']
      end
    else
      if @show_warped == "1"
        conditions =  ["status = 4 "]
      else
        conditions = nil
      end
    end
    @map = Map.public.paginate(:page => params[:page],
      :per_page => 10,
      :order => sort_clause,
      :conditions => conditions)
    @html_title = "Maps"
    respond_to do |format|
      format.html{ render :layout =>'application' }  # index.html.erb
      format.xml  { render :xml => @map }
    end
  end

  def export
    @current_tab = :export
    @html_title = "Export Map"
     respond_to do |format|
      format.html #export.html.erb
  end


  end

  def new
    @map = Map.new
    @html_title = "New Map"
    @max_size = Map.max_attachment_size
   if Map.max_dimension
      @upload_file_message  = " It may resize the image if it's too large (#{Map.max_dimension}x#{Map.max_dimension}) "
    else
      @upload_file_message = ""
    end

    respond_to do |format|
      format.html{ render :layout =>'application' }  # new.html.erb
      format.xml  { render :xml => @map }
    end
  end

  def create
    @map = Map.new(params[:map])

    if logged_in?
        @map.owner = current_user
        @map.users << current_user 
      end
   
    respond_to do |format|
      if @map.save
        flash[:notice] = 'Map was successfully created.'
        format.html { redirect_to(@map) }
        format.xml  { render :xml => @map, :status => :created, :location => @map }
      else
        format.html { render :action => "new", :layout =>'application' }
        format.xml  { render :xml => @map.errors, :status => :unprocessable_entity }
      end
    end
  end


  def edit
    @current_tab = :edit
    @html_title = "Edit metadata"
    @html_title = "Editing Map - " + @map.title
    respond_to do |format|
      format.html #{ render :layout =>'application' }  # new.html.erb
      format.xml  { render :xml => @map }
    end
  end

  def update
    #@map = Map.find(params[:id])
    respond_to do |format|
      if @map.update_attributes(params[:map])
        flash[:notice] = 'Map was successfully updated.'
        format.html { redirect_to(@map) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @map.errors, :status => :unprocessable_entity }
      end
    end
  end

  #only admins can do this
  def destroy
    map = Map.find(params[:id])
    if map.destroy 
      flash[:notice] = "map deleted"
    else
      flash[:notice] = "map wasnt deleted"
    end 
    respond_to do |format|
      format.html { redirect_to(maps_url) }
      format.xml  { head :ok }
    end
  end


  def status
    map = Map.find(params[:id])
    if map.status.nil?
      sta = "loading"
    else
      sta = map.status.to_s
    end
    render :text =>  sta 
  end

  def show

    @current_tab = :show
    @map = Map.find(params[:id])
    @html_title = "Map - " + @map.title
    if @map.status.nil? || @map.status == :unloaded
      @mapstatus = "unloaded"
    else
      @mapstatus = @map.status.to_s
    end
 
    #TODO temorary fix to stop non logged in users spamming
#    if !logged_in?
#
#      flash[:notice] = "You may need to log in to start editing the map"
#      render :action => "preview"
#      return #stop doing anything more
#    end
    #note, trying to view an image that hasnt been requested, will cause it to be requested
    if @map.status.nil? or @map.status == :unloaded
      @disabled_tabs = [:warp, :clip, :align, :warped, :activity]
      @title = "Viewing unrectified map."
      render :action => "preview"
      return

    end

    @title = "Viewing original map. "
    if @map.status != :warped
      @title += "This map has not been rectified yet."
    end

    respond_to do |format|
      format.html # show.html.erb
      #format.xml  { render :xml => @map }
    end

    # end
  end

  def clip
    @html_title = "Crop Map - " + @map.title
    @current_tab = :clip
    #   @map = Map.find(params[:id])
    @gml_exists = "false"
    if File.exists?(@map.masking_file_gml+".ol")
      @gml_exists = "true"
    end
  end

  #should check for admin only
  def publish
    #  @map = Map.find(params[:id])
    @map.publish
    render :text => "Map will be published. (this functionality doesn't do anything at the moment)"
  end

  def save_mask
    message = @map.save_mask(params[:output])
    render :text => message
  end

  def delete_mask
    message = @map.delete_mask
    render :text => message
  end

  def mask_map
    message = @map.mask!
    render :text => message
  end

  def save_mask_and_warp
    logger.info "save mask and warp"
    @map.save_mask(params[:output])
    @map.mask!
    if @map.gcps.size.nil? || @map.gcps.size < 3
      render :text => "Map masked, but it needs more control points to rectify. Click the Rectify tab to add some."
    else
      params[:use_mask] = "true"
      rectify
      render :text => "Map masked and rectified!"
    end

  end

  def warped
    @html_title = "Showing rectified map - " + @map.title
    @current_tab = :warped
    if @map.status == :warped and @map.gcps.size > 2
      @title = "Viewing warped map"
      width = @map.width
      height = @map.height

      respond_to do |format|
        format.html # show.html.erb
        #format.xml  { render :xml => @map }
      end
    else
      flash[:notice] = "Whoops, you have to rectify a map before you can view it"
      redirect_to :action => "show"
    end
  end

  def warp_aligned
    destmap = Map.find(params[:destmap])
    params[:id] = params[:destmap]
    align = params[:align].downcase

    append = params[:append]
    if params[:align_type]  == "original"
      result = destmap.align_with_original(params[:srcmap], align, append )
    else
      result = destmap.align_with_warped(params[:srcmap], align, append )
    end
    flash[:notice] = "map aligned"
    redirect_to :action => "warp", :id => destmap.id
  end

  def align
    @current_tab = :align
    @html_title = "Align Map - " + @map.title
    width = @map.width
    height = @map.height
  end

  def warp
    @html_title = "Rectify Map - " + @map.title
    @current_tab = :warp


    @gcps = @map.gcps_with_error

    width = @map.width
    height = @map.height
    width_ratio = width / 180
    height_ratio = height / 90

  end

  #TODO change rectify vs warp for nice route

  def rectify
    #gotta catch if user submits and there are no GCP's entered  - done :)
    #also
    ##catch if user submits a blank GCP. Message about minimum 3 ?
    #logger.info params.inspect
    resample_param = params[:resample_options]
    transform_param = params[:transform_options]
    masking_option = params[:mask]
    resample_option = ""
    transform_option = ""
    case transform_param
    when "auto"
      transform_option = ""
    when "p1"
      transform_option = " -order 1 "
    when "p2"
      transform_option = " -order 2 "
    when "p3"
      transform_option = " -order 3 "
    when "tps"
      transform_option = " -tps "
    else
      transform_option = ""
    end

    case resample_param
    when "near"
      resample_option = " -rn "
    when "bilinear"
      resample_option = " -rb "
    when "cubic"
      resample_option = " -rc "
    when "cubicspline"
      resample_option = " -rcs "
    when "lanczos" #its very very slow
      resample_option = " -rn "
    else
      resample_option = " -rn"
    end

    use_mask = params[:use_mask]
    @too_few = false
    if @map.gcps.size.nil? || @map.gcps.size < 3
      @too_few = true
      @notice_text = "Sorry, the map needs at least three control points to be able to rectify it"
      @output = @notice_text
    else
      if logged_in?
        um  = current_user.my_maps.new(:map => @map)
        um.save
        # @map.users << current_user # another way creating the relationship
      end

      @output = @map.warp! transform_option, resample_option, use_mask #,masking_option
      @notice_text = "Map rectified!"
    end

   redirect_to :action=> :index unless request.xhr?

  end



  begin
    include Mapscript if require 'mapscript'
    @@mapscript_exists = true
  rescue LoadError
    @@mapscript_exists = false
  end


  def wms
    @map = Map.find(params[:id])
    unless @@mapscript_exists
       mapserver_wms
    else

    #status is additional query param to show the unwarped wms
    status = params["STATUS"].to_s.downcase || "unwarped"
    ows = OWSRequest.new

    ok_params = Hash.new
    # params.each {|k,v| k.upcase! } frozen string error
    params.each {|k,v| ok_params[k.upcase] = v }
    [:request, :version, :transparency, :service, :srs, :width, :height, :bbox, :format, :srs].each do |key|
      ows.setParameter(key.to_s, ok_params[key.to_s.upcase]) unless ok_params[key.to_s.upcase].nil?
    end

    ows.setParameter("STYLES", "")
    ows.setParameter("LAYERS", "image")
    ows.setParameter("COVERAGE", "image")

    mapsv = MapObj.new(File.join(RAILS_ROOT, '/db/maptemplates/wms.map'))
    projfile = File.join(RAILS_ROOT, '/lib/proj')
    mapsv.setConfigOption("PROJ_LIB", projfile)
    #map.setProjection("init=epsg:900913")
    mapsv.applyConfigOptions
    rel_url_root =  (ActionController::Base.relative_url_root.blank?)? '' : ActionController::Base.relative_url_root
    mapsv.setMetaData("wms_onlineresource",
      "http://" + request.host_with_port + rel_url_root + "/maps/wms/#{@map.id}")

    raster = LayerObj.new(mapsv)
    raster.name = "image"
    raster.type = MS_LAYER_RASTER;

    if status == "unwarped"
      raster.data = @map.unwarped_filename

    else #show the warped map
      raster.data = @map.warped_filename
    end

    raster.status = MS_ON
    raster.dump = MS_TRUE
    raster.metadata.set('wcs_formats', 'GEOTIFF')
    raster.metadata.set('wms_title', @map.title)
    raster.metadata.set('wms_srs', 'EPSG:4326 EPSG:4269 EPSG:900913')
    raster.debug= MS_TRUE

    msIO_installStdoutToBuffer
    result = mapsv.OWSDispatch(ows)
    content_type = msIO_stripStdoutBufferContentType || "text/plain"
    result_data = msIO_getStdoutBufferBytes

    send_data result_data, :type => content_type, :disposition => "inline"
    msIO_resetHandlers
    end

  end

  private

   def mapserver_wms
    # @map = Map.find(params[:id])
    status = params["STATUS"].to_s.downcase || "unwarped"
    styles = "&styles=" # required to stop mapserver being pedantic on older versions
     if status == "unwarped"
      mapserver_url = '/cgi/mapserv.cgi' + '?map=' + @map.mapfile  + styles + "&layers=" + @map.id.to_s + "_original"
    else
      mapserver_url = '/cgi/mapserv.cgi' + '?map=' + @map.mapfile  + styles + "&layers=" + @map.id.to_s
    end
    mapserver_url += "&"+request.query_string
    redirect_to(mapserver_url)
  end

  def set_session_link_back link_url
    session[:link_back] = link_url
  end

  def check_link_back
    @link_back = session[:link_back]
    if @link_back.nil?
      @link_back = url_for(:action => 'index')
      #logger.info url_for(:action => 'index')
    end

    #if request.env["HTTP_REFERER"]
    #TODO need to change this if we go for /maps routes
    #not maps/
    #  if request.env["HTTP_REFERER"].include?("maps?") ||  request.env["HTTP_REFERER"][-8..-1]== "maps"
    #   @link_back = request.env["HTTP_REFERER"]
    # end
    # else
    #  @link_back = maps_path

    #end
    session[:link_back] = @link_back
  end

  #only allow editing by a user if the user owns it, or if no one owns it
  def check_if_map_is_editable

    if logged_in? && current_user.own_this_map?(params[:id])
      @map = Map.find(params[:id])
    elsif Map.find(params[:id]).owner.nil?
      @map = Map.find(params[:id])
    else
      flash[:notice] = "Sorry, you cannot edit other people's maps"
      redirect_to map_path
    end
  end

  def find_map_if_available
    @map = Map.find(params[:id])
    if @map.status.nil? or @map.status == :unloaded or @map.status == :loading
      # flash[:notice] = ""
      redirect_to map_path
    end
  end

end
