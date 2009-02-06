require "open3"
require "ftools"
require "matrix"
require 'erb'
include ErrorCalculator


class Map < ActiveRecord::Base
  has_many :my_maps, :dependent => :destroy
  has_many :users, :through => :my_maps
  belongs_to :owner, :class_name => "User"
  has_one :user, :through => :my_maps
  has_many :gcps,  :dependent => :destroy  #gcps also destroyed if map is
  
  has_attached_file :upload, :styles => { :medium => ["300x300>", :png ],
    :thumb => ["100x100>", :png]}
  attr_protected :upload_file_name, :upload_content_type, :upload_size


 #maximum dimension size for height or width. it will resize if one of the dimensions is over this value
 #define MAX_ATTACHMENT_SIZE in your config/environments/whatever.rb file

  validates_attachment_size(:upload, :less_than => MAX_ATTACHMENT_SIZE) if defined?(MAX_ATTACHMENT_SIZE)

  acts_as_audited :except => [:filename]

  named_scope :public, :conditions => ['public = ?', true]

  acts_as_enum :status, [:unloaded, :loading, :available, :warping, :warped, :published]
  acts_as_enum :mask_status, [:unmasked, :masking, :masked]

  default_values :status => :unloaded, :mask_status => :unmasked

  attr_accessor :error

  validates_presence_of :title

  before_create :save_dimensions
  after_create :setup_image
  after_destroy :delete_images
  after_destroy :delete_map


  #############################################
  #CUSTOM VALIDATIONS
  #############################################

  def validate_on_create
    errors.add(:filename, "is already being used") if Map.find_by_filename(upload.original_filename)
  end


  #############################################
  #FILTERS
  #############################################

  def save_dimensions
    if ["image/jpeg", "image/tiff", "image/png", "image/gif", "image/bmp"].include?(upload.content_type.to_s)
      self.width = upload.width
      self.height = upload.height
    end
    self.status = :available
  end

  #this gets the upload, detects what it is, and converts to a tif, if necessary.
  #Although an uploaded tif with existing geo fields may confuse things
  def setup_image
    logger.info "setup_image "
    self.filename = upload.original_filename
    save!
    if self.upload?
   
      if  defined?(MAX_DIMENSION) && (width > MAX_DIMENSION || height > MAX_DIMENSION)
        logger.info "Image is too big, so going to resize "
        if width > height
          dest_width = MAX_DIMENSION
          dest_height = (dest_width.to_f /  width.to_f) * height.to_f
        else
          dest_height = MAX_DIMENSION
          dest_width = (dest_height.to_f /  height.to_f) * width.to_f
        end
        outsize = "-outsize #{dest_width.to_i} #{dest_height.to_i}"
      else
        outsize = ""
      end

      orig_ext = File.extname(self.upload_file_name).to_s.downcase
      i_stdin, i_stdout, i_stderr =
        Open3::popen3( "#{GDAL_PATH}gdalinfo #{self.upload.path} -nomd -noct" )
      
      i_stdout.readlines.to_s.include?("ColorInterp=Gray")?   gray = true  :   gray = false

#      if gray == true && (orig_ext != ".tif" || orig_ext != ".tiff")
#        logger.info("converting to truecolor")
#        `convert  #{self.upload.path} -type TrueColor #{self.upload.path + "_tmp"}`
#        File.copy self.upload.path + "_tmp", self.upload.path
#      end

      tiffed_filename = (orig_ext == ".tif" || orig_ext == ".tiff")? self.upload_file_name : self.upload_file_name + ".tif"
      tiffed_file_path = File.join(maps_dir , tiffed_filename)

      if (orig_ext == ".tif" || orig_ext == ".tiff") && !gray && !outsize.empty?
        logger.info "Upload is a TIF and is not gray, and is not oversized so just copy original"
        self.filename = upload.original_filename
        File.copy self.upload.path, maps_dir
      else 
        logger.info "It's 1) a TIF and gray, or 2) its a normal image, either way, we convert to tiff"
        # -co compress=DEFLATE for compression?
        ti_stdin, ti_stdout, ti_stderr =
          Open3::popen3( "#{GDAL_PATH}gdal_translate #{self.upload.path} #{outsize} -co PHOTOMETRIC=RGB -co profile=baseline #{tiffed_file_path}" )
        self.filename = tiffed_filename
      end
    end

    save!
    save_mapfile
  end

  #paperclip plugin deletes the images when model is destroyed
  def delete_images
    logger.info "Deleting map images"
    if File.exists?(temp_filename)
      logger.info "deleted temp"
      File.delete(temp_filename)
    end
    if File.exists?(warped_filename)
      logger.info "Deleted Map warped"
      File.delete(warped_filename)
    end
    if File.exists?(warped_png)
      logger.info "deleted warped png"
      File.delete(warped_png)
    end
    if File.exists?(unwarped_filename)
      logger.info "deleting unwarped"
      File.delete unwarped_filename
    end
  end

  def delete_map
    logger.info "Deleting mapfile"

  end

  #############################################
  #ACCESSOR METHODS
  #############################################

  def maps_dir
    File.join(RAILS_ROOT, "/public/mapimages/src/")
  end

  def dest_dir
    File.join(RAILS_ROOT, "/public/mapimages/dst/")
  end

  def mapfile
    RAILS_ROOT+"/db/mapfiles/"+self.id.to_s+".map"
  end

  def warped_dir
    dest_dir
  end

  def unwarped_filename
    File.join(maps_dir, self.filename)
  end

  def warped_filename
    File.join(warped_dir, id.to_s) + ".tif"
  end

  def warped_png
    warped_filename + ".png"
  end

  def public_warped_tif_url
    "mapimages/dst/"+id.to_s + ".tif"
  end
  def public_warped_png_url
    public_warped_tif_url + ".png"
  end

  def mask_file_format
    "gml"
  end

  def temp_filename
    # self.full_filename  + "_temp"
    File.join(warped_dir, id.to_s) + "_temp"
  end

  def masking_file
    File.join(RAILS_ROOT, "/public/mapimages/",  self.id.to_s) + ".json"
  end

  def masking_file_gml
    File.join(RAILS_ROOT, "/public/mapimages/",  self.id.to_s) + ".gml"
  end

  def masked_src_filename
    self.unwarped_filename + "_masked"
  end


  #############################################
  #CLASS METHODS
  #############################################
  
  def self.max_attachment_size
  max_attachment_size =  defined?(MAX_ATTACHMENT_SIZE)? MAX_ATTACHMENT_SIZE : nil
  end

  def self.max_dimension
     max_dimension = defined?(MAX_DIMENSION)? MAX_DIMENSION : nil
  end
  #saves tilecache's config file
  def self.save_tilecache_config
    @maps = Map.all(:conditions => "status = 4")

    cfg = File.open(RAILS_ROOT+"/public/cgi/tilecache.cfg",  File::CREAT|File::TRUNC|File::RDWR, 0666)
    template = File.open(RAILS_ROOT + "/db/maptemplates/tilecache.text.erb").read
    cfg.puts ERB.new(template).result( binding )
    cfg.close
  end


  #############################################
  #INSTANCE METHODS
  #############################################

  def available?
    return [:available,:warping,:warped].include?(status)
  end

  def last_changed
    if self.gcps.size > 0
      self.gcps.last.created_at
    elsif !self.updated_at.nil?
      self.updated_at
    elsif !self.created_at.nil?
      self.created_at
    else
      Time.now
    end
  end

  def bounds
    x_array = []
    y_array = []
    self.gcps.each do |gcp|
      #logger.info "GCP lat #{gcp[:lat]} , lon #{gcp[:lon]} "
      x_array << gcp[:lat]
      y_array << gcp[:lon]
    end
    our_bounds = [y_array.min ,x_array.min ,y_array.max, x_array.max].join ','
  end

  def converted_bbox
    bnds = self.bounds.split(",")
    cbounds = []
    c_in, c_out, c_err =
      Open3::popen3("echo #{bnds[0]} #{bnds[1]} | #{GDAL_PATH}cs2cs +proj=latlong +datum=WGS84 +to +proj=merc +ellps=sphere +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0")
    info = c_out.readlines.to_s
    string,cbounds[0], cbounds[1] = info.match(/([-.\d]+)\s*([-.\d]+).*/).to_a
    c_in, c_out, c_err =
      Open3::popen3("echo #{bnds[2]} #{bnds[3]} | #{GDAL_PATH}cs2cs +proj=latlong +datum=WGS84 +to +proj=merc +ellps=sphere +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0")
    info = c_out.readlines.to_s
    string,cbounds[2], cbounds[3] = info.match(/([-.\d]+)\s*([-.\d]+).*/).to_a
    cbounds.join(",")
  end


  #method to publish the map to cluster
  def publish
    #self.status = :published
    #save!
  end

  #attempts to align based on the extent and offset of the
  #reference map's warped image
  #results it nicer gpcs to edit with later
  def align_with_warped (srcmap, align = nil, append = false)
    srcmap = Map.find(srcmap)
    origgcps = srcmap.gcps

    #clear out original gcps, unless we want to append the copied gcps to the existing ones
    self.gcps.destroy_all unless append == true

    #extent of source from gdalinfo
    stdin, stdout, sterr = Open3::popen3("#{GDAL_PATH}gdalinfo #{srcmap.warped_filename}")
    info = stdout.readlines.to_s
    string_lw,west,south = info.match(/Lower Left\s+\(\s*([-.\d]+), \s+([-.\d]+)/).to_a
    string_ur,east,north = info.match(/Upper Right\s+\(\s*([-.\d]+), \s+([-.\d]+)/).to_a

    lon_shift = west.to_f - east.to_f
    lat_shift = south.to_f - north.to_f

    origgcps.each do |gcp|
      a = Gcp.new()
      a = gcp.clone
      if align == "east"
        a.lon -= lon_shift
      elsif align == "west"
        a.lon += lon_shift
      elsif align == "north"
        a.lat -= lat_shift
      elsif align == "south"
        a.lat += lat_shift
      else
        #if no align, then dont change the gcps
      end
      a.map = self
      a.save
    end

    newgcps = self.gcps
  end

  #attempts to align based on the width and height of
  #reference map's un warped image
  #results it potential better fit than align_with_warped
  #but with less accessible gpcs to edit
  def align_with_original(srcmap, align = nil, append = false)
    srcmap = Map.find(srcmap)
    origgcps = srcmap.gcps

    #clear out original gcps, unless we want to append the copied gcps to the existing ones
    self.gcps.destroy_all unless append == true
       
    origgcps.each do |gcp|
      new_gcp = Gcp.new()
      new_gcp = gcp.clone
      if align == "east"
        new_gcp.x -= srcmap.width
           
      elsif align == "west"
        new_gcp.x += srcmap.width
      elsif align == "north"
        new_gcp.y += srcmap.height
      elsif align == "south"
        new_gcp.y -= srcmap.height
      else
        #if no align, then dont change the gcps
      end
      new_gcp.map = self
      new_gcp.save
    end

    newgcps = self.gcps
  end

  # map gets error attibute set and gcps get error attribute set
  def gcps_with_error
    gcps = Gcp.find(:all, :conditions =>["map_id = ?", self.id], :order => 'created_at')
    gcps, map_error = ErrorCalculator::calc_error(gcps)
    @error = map_error
    #send back the gpcs with error calculation
    gcps
  end

  #Main warp method
  def warp!(resample_option, transform_option, use_mask="false")

    self.status = :warping
    save!

    gcp_array = self.gcps

    gcp_string = ""

    gcp_array.each do |gcp|
      gcp_string = gcp_string + gcp.gdal_string
    end

    mask_options = ""
    if use_mask == "true" && self.mask_status == :masked
      src_filename = self.masked_src_filename
      mask_options = " -srcnodata '17 17 17' "
    else
      src_filename = self.unwarped_filename
    end

    dest_filename = self.warped_filename
    temp_filename = self.temp_filename

    #delete existing temp images @map.delete_images
    if File.exists?(dest_filename)
      File.delete(dest_filename)
    end

    logger.info "gdal translate"

    t_stdin, t_stdout, t_stderr = Open3::popen3(
      "#{GDAL_PATH}gdal_translate -a_srs '+init=epsg:4326' -of VRT #{src_filename} #{temp_filename}.vrt #{gcp_string}"
    )

    logger.info "gdal_translate -a_srs '+init=epsg:4326' -of VRT #{src_filename} #{temp_filename}.vrt #{gcp_string}"
    t_out  = t_stdout.readlines.to_s
    t_err = t_stderr.readlines.to_s

    if t_err.size > 0
      logger.error "ERROR gdal translate script: "+ t_err
      logger.error "Output = " +t_out
      t_out = "ERROR with gdal translate script: " + t_err + "<br /> You may want to try it again? <br />" + t_out
    else
      t_out = "Okay, translate command ran fine! <div id = 'scriptout'>" + t_out + "</div>"
    end

    trans_output = t_out

  ##  memory_limit = (SITE_URL == "warper.geothings.net") ? "-wm 20" : ""
   memory_limit =  (defined?(GDAL_MEMORY_LIMIT)) ? "-wm "+GDAL_MEMORY_LIMIT.to_s :  ""
    #check for  -dstnodata  255 or -dstalpha  ColorInterp=Palette
    #One of Gray, Palette, Red, Green, Blue, Alpha, Hue, Saturation, Lightness, Cyan, Magenta, Yellow, Black, or Unknown
    i_stdin, i_stdout, i_stderr = Open3::popen3(
      "#{GDAL_PATH}gdalinfo #{src_filename} -nomd -noct"
    )
    nodata_alpha = ""
    if !i_stdout.readlines.to_s.match("Interp=Palet").nil?
      nodata_alpha = "-dstnodata 255"
    else
      nodata_alpha = "-dstalpha "
    end
    w_tdin, w_stdout, w_stderr = Open3::popen3(
      "#{GDAL_PATH}gdalwarp #{memory_limit} #{transform_option}  #{resample_option} #{nodata_alpha} #{mask_options} -s_srs 'EPSG:4326' #{temp_filename}.vrt #{dest_filename} -co TILED=YES  "
    )
    #emergency fix removed -co ALPHA=YES
    logger.info "gdalwarp #{memory_limit} #{transform_option}  #{resample_option} #{nodata_alpha} #{mask_options}  #{temp_filename}.vrt #{dest_filename} -co TILED=YES  "

    w_out = w_stdout.readlines.to_s
    w_err = w_stderr.readlines.to_s
    if w_err.size > 0
      logger.error "Error gdal warp script" + w_err
      logger.error "output = "+w_out
      w_out = "error with gdal warp: "+ w_err +"<br /> try it again?<br />"+ w_out
    else
      w_out = "Okay, warp command ran fine! <div id='scriptout'>" + w_out +"</div>"
    end

    if File.exists?(temp_filename + '.vrt')
      logger.info "deleted temp vrt file"
      File.delete(temp_filename + '.vrt')
    end

    warp_output = w_out

    if w_err.size <= 0 and t_err.size <= 0
      self.status = :warped
      convert_to_png(dest_filename)
    else
      self.status = :available
    end
    save!
    output = "Step 1: Translate: "+ trans_output + "<br />Step 2: Warp: " + warp_output
  end

  def mask!

    self.mask_status = :masking
    save!
    format = self.mask_file_format

    if format == "gml"
      return "no masking file found, have you created a clipping mask and saved it?"  unless File.exists?(masking_file_gml)
      masking_file = self.masking_file_gml
      layer = "features"
    elsif format == "json"
      return "no masking file found, have you created a clipping mask and saved it?"  unless File.exists?(masking_file_json)
      masking_file = self.masking_file_json
      layer = "OGRGeoJson"
    else
      return "no masking file matching specified format found."
    end

    masked_src_filename = self.masked_src_filename
    File.delete(masked_src_filename) if File.exists?(masked_src_filename)
    #copy over orig to a new unmasked file
    File.copy(unwarped_filename, masked_src_filename)


    r_stdin, r_stdout, r_stderr = Open3::popen3(
      "#{GDAL_PATH}gdal_rasterize -i -burn 17 -b 1 -b 2 -b 3 #{masking_file} -l #{layer} #{masked_src_filename}"
    )
    logger.info "gdal_rasterize -i -burn 17 -b 1 -b 2 -b 3 #{masking_file} -l #{layer} #{masked_src_filename}"
    r_out  = r_stdout.readlines.to_s
    r_err = r_stderr.readlines.to_s
    if r_err.size > 0
      #error, need to fail nicely
      logger.error "ERROR gdal rasterize script: "+ r_err
      logger.error "Output = " +r_out
      r_out = "ERROR with gdal rasterise script: " + r_err + "<br /> You may want to try it again? <br />" + r_out
    else
      # r_out = "Okay, rasterise command ran fine! <div id = 'scriptout'>" + r_out + "</div>"

      r_out = "Success! Map was cropped!"
    end

    self.mask_status = :masked
    save!
    r_out
  end

  # gdal_rasterize -i -burn 17 -b 1 -b 2 -b 3 SSS.json -l OGRGeoJson orig.tif
  # gdal_rasterize -burn 17 -b 1 -b 2 -b 3 SSS.gml -l features orig.tif
  
  def delete_mask
    logger.info "delete mask"
    if File.exists?(self.masking_file_gml)
      File.delete(self.masking_file_gml)
    end
    if File.exists?(self.masking_file_gml+".ol")
      File.delete(self.masking_file_gml+".ol")
    end

    self.mask_status = :unmasked
    save!
    "mask deleted"
  end


  def save_mask(vector_features)
    if self.mask_file_format == "gml"
      msg = save_mask_gml(vector_features)
    elsif self.mask_file_format == "json"
      msg = save_mask_json(vector_features)
    else
      msg = "Mask format unknown"
    end
    msg
  end


  #parses geometry from openlayers, and saves it to file.
  #GML format
  def save_mask_gml(features)
    if File.exists?(self.masking_file_gml)
      File.delete(self.masking_file_gml)
    end
    if File.exists?(self.masking_file_gml+".ol")
      File.delete(self.masking_file_gml+".ol")
    end
    origfile = File.new(self.masking_file_gml+".ol", "w+")
    origfile.puts(features)
    origfile.close

    doc = REXML::Document.new features
    REXML::XPath.each( doc, "//gml:coordinates") { | element|
      # blimey element.text.split(' ').map {|i| i.split(',')}.map{ |i| i[0] => i[1]}.inject({}){|i,j| i.merge(j)}
      coords_array = element.text.split(' ')
      new_coords_array = Array.new
      coords_array.each do |coordpair|
        coord = coordpair.split(',')
        coord[1] = self.height - coord[1].to_f
        newcoord = coord.join(',')
        new_coords_array << newcoord
      end
      element.text = new_coords_array.join(' ')

    } #element
    gmlfile = File.new(self.masking_file_gml, "w+")
    doc.write(gmlfile)
    gmlfile.close
    message = "Map clipping mask saved (gml)"
  end

  #parses geometry from openlayers, and saves it to file.
  #JSON format
  def save_mask_json(features)
    if File.exists?(self.masking_file_json)
      File.delete(self.masking_file_json)
    end

    image_height = self.height
    json = ActiveSupport::JSON.decode(features)
    message = "Nothing saved, something may have gone wrong"
    if json["features"].length <= 0
      message = "Nothing saved, you have to draw a polygon on the map first"
    else
      json["features"].each do |feature|
        coords = feature["geometry"]["coordinates"]
        coords[0].each do |coord|
          # x = coord[0]
          coord[1] = image_height - coord[1]
        end
      end
      new_json = ActiveSupport::JSON.encode(json)
      jsonfile = File.new(self.masking_file, "w+")
      jsonfile.puts new_json
      jsonfile.close
      message = "Map clipping mask saved"
    end
    message
  end

  #can put more things under here?

  ############
  #PRIVATE
  ############
  #saves the map to its own mapfile for use with wms mapserver
  def save_mapfile
    map_title = ERB::Util.html_escape title

    map_title.gsub!(/\W+/, ' ')
    map_filename = ERB::Util.html_escape self.warped_filename
    map_layer_name = id

    map_original_layer_name = id.to_s + "_original"
    map_original_filename =  ERB::Util.html_escape self.unwarped_filename  # self.upload.path
     
    ourmapfile  = File.open(self.mapfile, File::CREAT|File::TRUNC|File::RDWR, 0666)
    template = File.open(RAILS_ROOT+"/db/maptemplates/mapfile.text.erb").read
     
    ourmapfile.puts ERB.new(template).result( binding )
    ourmapfile.close
  end

  def convert_to_png(filename)
    logger.info "convert to png"
    warped_png = filename + ".png"
    stdin, stdout, stderr = Open3::popen3("#{GDAL_PATH}gdal_translate -of png #{filename} #{warped_png}")
    #logger.info stdout.readlines.to_s
    logger.info "#{filename} -> #{warped_png}"
  end


end
