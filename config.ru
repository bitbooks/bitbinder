# Added for starting up the Sinatra endpoint

# Add the data directory unless it already exists
# (This is a build step because git won't move empty directories)
Dir.mkdir 'data' unless File.directory?('data')

require "./endpoint.rb"
run Builder::App