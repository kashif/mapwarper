module Paperclip
  # Handles thumbnailing images that are uploaded.
 
  class Thumbnail

    attr_accessor :file, :current_geometry, :original_filename, :target_geometry, :format, :whiny_thumbnails, :convert_options

    # Creates a Thumbnail object set to work on the +file+ given. It
    # will attempt to transform the image into one defined by +target_geometry+
    # which is a "WxH"-style string. +format+ will be inferred from the +file+
    # unless specified. Thumbnail creation will raise no errors unless
    # +whiny_thumbnails+ is true (which it is, by default. If +convert_options+ is
    # set, the options will be appended to the convert command upon image conversion
    def initialize file, original_filename, target_geometry, format = nil, convert_options = nil, whiny_thumbnails = true
      @original_filename = original_filename
      @file             = file
      @crop             = target_geometry[-1,1] == '#'
      @target_geometry  = Geometry.parse target_geometry
      @current_geometry = Geometry.from_file file
      @convert_options  = convert_options
      @whiny_thumbnails = whiny_thumbnails

      @current_format   = File.extname(@file.path)
      @basename         = File.basename(@file.path, @current_format)

      @format = format
    end

    # Creates a thumbnail, as specified in +initialize+, +make+s it, and returns the
    # resulting Tempfile.
    def self.make file, original_filename, dimensions, format = nil, convert_options = nil, whiny_thumbnails = true
      new(file, original_filename, dimensions, format, convert_options, whiny_thumbnails).make
    end

    # Returns true if the +target_geometry+ is meant to crop.
    def crop?
      @crop
    end

    # Returns true if the image is meant to make use of additional convert options.
    def convert_options?
      not @convert_options.blank?
    end

    # Performs the conversion of the +file+ into a thumbnail. Returns the Tempfile
    # that contains the new image.
    def make
      src = @file
      dst = Tempfile.new([@basename, @format].compact.join("."))
      dst.binmode
      
      command = <<-end_command
      "#{ File.expand_path(src.path) }[0]"
      #{ transformation_command }
      "#{ File.expand_path(dst.path) }"
      end_command

      orig_ext = File.extname(@original_filename).to_s.downcase
    
      if orig_ext == ".tif" || orig_ext == ".tiff"
        puts "using gdal to make thumbs"
        dest_format = @format
        dest_w = @target_geometry.width
        dest_h = @target_geometry.height

        #fixed height, and flexible width
        unless @current_geometry.square?
          dest_h = (@target_geometry.width / @current_geometry.width) * @current_geometry.height
        end

        #o_format = (@format.to_s.upcase == "JPG")? "PNG" : @format.to_s.upcase
        o_format = "PNG"
        gdal_transformation_command = "-of #{o_format} -outsize #{dest_w.to_i} #{dest_h.to_i} "
      
        gdal_command = <<-end_command
          #{ gdal_transformation_command }
         "#{ File.expand_path(src.path) }"
         "#{ File.expand_path(dst.path) }"
        end_command
    
        begin
          success = Paperclip.run("#{GDAL_PATH}gdal_translate", gdal_command.gsub(/\s+/, " "))
        rescue PaperclipCommandLineError
          raise PaperclipError, "There was an error processing the thumbnail (GDAL) for #{@basename}" if @whiny_thumbnails
        end

        
      else

        begin
          success = Paperclip.run("convert", command.gsub(/\s+/, " "))
        rescue PaperclipCommandLineError
          raise PaperclipError, "There was an error processing the thumbnail (Imagemagick) for #{@basename}" if @whiny_thumbnails
        end

      end

      dst
    end

    # Returns the command ImageMagick's +convert+ needs to transform the image
    # into the thumbnail.
    def transformation_command
      scale, crop = @current_geometry.transformation_to(@target_geometry, crop?)
      trans = "-resize \"#{scale}\""
      trans << " -crop \"#{crop}\" +repage" if crop
      trans << " #{convert_options}" if convert_options?
      trans
    end
  end

  # Due to how ImageMagick handles its image format conversion and how Tempfile
  # handles its naming scheme, it is necessary to override how Tempfile makes
  # its names so as to allow for file extensions. Idea taken from the comments
  # on this blog post:
  # http://marsorange.com/archives/of-mogrify-ruby-tempfile-dynamic-class-definitions
  class Tempfile < ::Tempfile
    # Replaces Tempfile's +make_tmpname+ with one that honors file extensions.
    def make_tmpname(basename, n)
      extension = File.extname(basename)
      sprintf("%s,%d,%d%s", File.basename(basename, extension), $$, n, extension)
    end
  end
end

