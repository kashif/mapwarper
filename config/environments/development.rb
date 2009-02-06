# Settings specified here will take precedence over those in config/environment.rb
SITE_URL = "localhost:3000"
SITE_NAME = "map warper"
SITE_EMAIL = "robot@localhost"

#MAX_DIMENSION =  2000
#MAX_ATTACHMENT_SIZE = 100.megabytes
#GDAL_MEMORY_LIMIT = 30 #in mb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.

#if we want auditing in dev mode, we gotta set these to true see above# it sucks for dev. 
config.cache_classes = false
config.action_controller.perform_caching             = false


# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_view.debug_rjs                         = true


# Don't care if the mailer can't send
config.action_mailer.raise_delivery_errors = false

GDAL_PATH  = ""
