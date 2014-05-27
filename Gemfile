# If you have OpenSSL installed, we recommend updating
# the following line to use "https"
source 'http://rubygems.org'
ruby '1.9.3' # Added by Bryan, for labeling the version of Ruby we are using. @todo, add a .rubyversion file for

gem "middleman", "~> 3.3.2"
gem "middleman-syntax"
gem "redcarpet" # For github-flavored markdown
gem "titleize", "~> 1.3.0" # For title-casing things
gem "middleman-navtree"
gem "middleman-bitbooks", path: "vendor/gems/middleman-bitbooks"

group :development do
  gem "middleman-livereload", "~> 3.1.0"
  # For debugging
  gem "pry", :require => true
  gem "pry-remote", :require => true
  gem 'pry-debugger', :require => true
  gem "pry-doc"
end

# Cross-templating language block fix for Ruby 1.8
platforms :mri_18 do
  gem "ruby18_source_location"
end

# Gems Required for Bitbooks builds. Not to be included in the Open source
# Franklin Project.
gem "sinatra"
gem "octokit"
gem "attr_encrypted"