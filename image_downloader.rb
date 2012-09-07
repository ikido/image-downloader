require 'net/http'

################################### DESCRIPTION ###############################

# Looks for all images on a page by pattern - path and extension

# Uses only Net::HTTP and URI modules, built in ruby
# STDLIB

# Sometimes images may be just metioned in text (like 1.jpg), they will 
# be treated as relative to current page, and if not exist (with is probably
# the case) will return 404 errors

################################### SETUP #####################################

# Default user agent, stay undercover
@user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_0) "+
  "AppleWebKit/536.3 (KHTML, like Gecko) Chrome/19.0.1063.0 Safari/536.3"

# Regex to get relative & absolute paths to images
@image_regex = /(http:\/\/|https:\/\/)?([\w\d\.\/,;:\-_\?%&+#=]+)(\.jpg|\.bmp|\.gif|\.png|\.svg|\.tiff)/im

################################### FUNCTIONS #################################

# Logs message, currently to STDOUT
def log(message = nil)
  puts message if message
end

# Logs and return 1
def log_error_and_exit(message = "")
  log "Error: #{message}"
  exit 1
end

# Normalize url - add protocol & trailing slash if necessary
def check_and_normalize_url(url_string)
  url = URI.parse(url_string)
  
  # Double parse is workaround due to a bug in URI module, 
  # append protocol if not set
  unless url.host && url.port
    url = URI.parse(URI.parse("http://#{url_string}").to_s) 
  end
  
  # Raise exception if we can't get host & port even after 
  # adding default protocol (Net::HTTP throws exception in Get method 
  # for Net::HTTP::Generic class)  
  unless url.host && url.port
    raise ArgumentError, "Error parsing url \"#{url}\"" 
  else
    url
  end
end

# Main function to fetch remote url via Net::HTTP
def fetch_url(url, limit = 10)
  url = check_and_normalize_url(url) unless url.class.name == 'URI::HTTP'
  
  # If no path in the url, fetch root
  url.path = "/" if url.path == ""
  
  # This is last redirect, enough is enough
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0
  
  request = Net::HTTP::Get.new(url.path, { 'User-Agent' => @user_agent })
  response = Net::HTTP.start(url.host, url.port) do |http| 
    http.request(request)
  end
  
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then fetch_url(response['location'], limit - 1)
  else
    puts response.error!
  end
end

################################### CODE ######################################

# Log & exit with error if no url specified
unless ARGV.size == 1
  puts "Usage: ruby download_images.rb http://en.wikipedia.org/wiki/Gustav_Klimt"
  puts "Remember to specify protocol (http://) and trailing slash "+
       "for main pages (http://en.wikipedia.org/)"
       
  log_error_and_exit "Error: No url specified or too many options"
end


# Normalize specified url
begin
  # Save for later use with relative urls of images
  @page_url = check_and_normalize_url(ARGV[0])
rescue ArgumentError => error
  log_error_and_exit(error)
end


# Get page, specified in command line
begin
  page = fetch_url(@page_url)
# Generic error, usually problem with url, specified by user
rescue ArgumentError => error 
  log_error_and_exit(error)
# URI has some specific problems with url 
rescue URI::InvalidURIError => error
  log_error_and_exit(error)
# Server returned an error - e.g. 404
rescue Net::HTTPServerException => error
  log_error_and_exit(error)
# Can't connect to server - e.g. host do not exist
rescue SocketError => error
  log_error_and_exit(error)
end



# Create directory for images, if necessary
timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
clean_host = @page_url.host.gsub(/(\W|\d)/, "")
@dir_full_path = File.join(Dir.pwd, "#{clean_host}_#{timestamp}") 

begin
  Dir.mkdir(@dir_full_path) unless File.exists?(@dir_full_path)
rescue
  log_error_and_exit "Error: unable to create directory to save images to"
end


# Go trough all images that match our super-image-catching-regex
images = page.body.scan(@image_regex)
@total_images = images.size
images.each_with_index do |image, i|
  image_url = image.compact.join('')
  
  # In case we have path relative path (starts from slash or 
  # do not have it at all)
  if image_url.match /^\// or not image_url.match /\//
    image_url = URI.join(@page_url.to_s, image_url)
  end
  
  begin
    image_file = fetch_url(image_url)
    
    # If it's not an image, log error, otherwise save to current dir
    if image_file['content-type'] =~ /^image\//
      filename = image_url.to_s.split('/').pop
      
      # image is saved to current dir in separate folder, created earlier
      full_path = File.join(@dir_full_path, filename) 
      
      begin
        File.open(full_path ,"wb") do |file|
          file.write(image_file.body)
        end
      rescue
        log "Image #{i+1}/#{@total_images}, #{image_url}: Error, unable to save image"
      end
      
      log "Downloaded image #{i+1}/#{@total_images}, #{image_url}"
    else
      log "Image #{i+1}/#{@total_images}, #{image_url}: Not an image file"
    end
    
  rescue ArgumentError => error
    log "Image #{i+1}/#{@total_images}, #{image_url}: #{error}"
  rescue URI::InvalidURIError => error
    log "Image #{i+1}/#{@total_images}, #{image_url}: #{error}"
  rescue Net::HTTPServerException => error
    log "Image #{i+1}/#{@total_images}, #{image_url}: #{error}"
  rescue SocketError => error
    log "Image #{i+1}/#{@total_images}, #{image_url}: #{error}"
  end
end