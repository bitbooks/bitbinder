# This is a tiny sinatra application, who's only job is to create an
# endpoint for other services to trigger a middleman build.
#
# Turn on the endpoint by running the file:
#
#   rackup
#
# This file should not be included in the Open Source Franklin project.
# Can this be part of my Bitbooks Gem somehow (in order to separate from
# Franklin)? Possibly.
require 'sinatra'
require 'json'
require 'yaml'
require 'octokit'
require 'securerandom'
require 'open3'
require 'fileutils'
require 'attr_encrypted'

# Environment Variables (with dummy placeholders)
SECRET_KEY = ENV['SECRET_KEY'] || '12345'
BITBOOKS_PASS = ENV['BITBOOKS_PASS'] || '12345'

module Builder
  class App < Sinatra::Base

    # Lock down all the routes with basic authentication (see
    # http://www.sinatrarb.com/faq.html#auth). This isn't bulletproof, but it is
    # another layer of protection.
    use Rack::Auth::Basic, "Restricted Area" do |username, password|
      username == 'bitbooks' and password == BITBOOKS_PASS
    end

    post '/build' do
      @datahash = JSON.parse(params[:data])
      encryptedtoken = @datahash.delete("token")
      @token = Encryptor.decrypt(Base64.decode64(encryptedtoken), :key => SECRET_KEY)
      IO.write(data_path, YAML::dump(@datahash))

      perform_build if github.scopes.include?("public_repo") || github.scopes.include?("repo")
      status 200
    end

    post '/copy' do
      @datahash = JSON.parse(params[:data])
      encryptedtoken = @datahash.delete("token")
      @token = Encryptor.decrypt(Base64.decode64(encryptedtoken), :key => SECRET_KEY)

      clone_and_push if github.scopes.include?("public_repo") || github.scopes.include?("repo")
      status 200
    end

    get '/' do
      # Just to make sure the server is running.
      "hello world"
    end

    def perform_build
      begin
        pull_source
        middleman_build
        push_up
      ensure
        FileUtils.rm_rf build_path
        FileUtils.rm_rf temp_source_path
      end
    end

    def pull_source
      # I'd prefer to clone over pull because it seems faster, but we'll settle for this.
      FileUtils.cp_r source_path, temp_source_path
      Dir.chdir temp_source_path
      Open3.capture2 "git", "init"
      Open3.capture2 "git", "remote", "add", "downstream", "#{destination.scheme}://#{destination.host}/#{@datahash['gh_full_name']}.git"
      Open3.capture2 "git", "pull", "--quiet", "downstream", "master"
    end

    def middleman_build
      Dir.chdir root
      Open3.capture2 "middleman", "build"
    end

    def push_up
      # Temporarily instatiate a git repo.
      # @todo: I don't think this is an issue inside of our existing git
      # repo, since we throw it away afterwards, but we ought to check.
      Dir.chdir build_path
      Open3.capture2 "git", "init"
      Open3.capture2 "git", "add", "-A"
      Open3.capture2 "git", "commit", "-m", "Another change, by your friendly neighborhood Bitbooks robot."
      Open3.capture2 "git", "branch", "-m", "gh-pages"
      Open3.capture2 "git", "remote", "add", "downstream", destination_remote
      Open3.capture2 "git", "push", "downstream", "gh-pages", "--force"
    end

    def clone_and_push
      if repo_exists?
        # This is a double-check because it's already checked once before the job is queued.
        # However, this check keeps the job idempotent... which is imporatnat.
        # @todo: This is crude error reporting. Determine the best way to do this in for production.
        Open3.capture2 "echo", "Could not copy the repo, because the destination repository already exists."
      else
        FileUtils.rm_rf repo_path # Not sure why I need this, but it existed in copy-to.
        Dir.chdir root
        begin
          # @todo: pass in the "website" paramter, so it points to github pages.
          github.create_repository "starter-book" # Create empty repo on github.
          Open3.capture2 "git", "clone", "--quiet", "#{destination.scheme}://#{destination.host}/bitbooks/starter-book.git", repo_path
          Dir.chdir repo_path
          Open3.capture2 "git", "remote", "add", "downstream", destination_remote
          Open3.capture2 "git", "push", "downstream", 'master'
        ensure
          FileUtils.rm_rf repo_path
        end
      end
    end

    def repo_exists?
      github.repository @datahash['gh_full_name']
    rescue Octokit::NotFound
      false
    end

    def destination
      URI.parse Octokit.web_endpoint
    end

    def destination_remote
      "#{destination.scheme}://#{@token}:x-oauth-basic@#{destination.host}/#{@datahash['gh_full_name']}.git"
    end

    # This is the main function for interfacing with the Github API. Unfortunately,
    # I had to make it more verbose in order to handle unauthorize errors (using
    # validate_credentials()... the rescue block just didn't seem to work). Maybe
    # some day I can get it back to the simplicity of "app_client" below it.
    def github
      client_object_exists = (defined?(@github) != nil)
      if client_object_exists
        return @github
      else
        if Octokit.validate_credentials({ :access_token => @token })
          @github = Octokit::Client.new :access_token => @token
        else
          # Serves as a semi-protection since nobody can make these endpoints
          # do anything unless they have a valid Oauth code.
          halt 401, "Not authorized\n"
        end
      end
    end

    # Older, simpler version of the function above.
    # def github
    #   @github ||= Octokit::Client.new :access_token => @token
    # end

    def root
      @root ||= File.expand_path File.dirname(__FILE__)
    end

    # For copy-to
    def repo_path
      @repo_path ||= File.expand_path "./#{SecureRandom.hex}", root
    end

    def build_path
      @build_path ||= File.expand_path "./build", root
    end

    def data_path
      @data_path ||= File.expand_path "./data/book.yml", root
    end

    def source_path
      @source_path ||= File.expand_path "./source", root
    end

    def temp_source_path
      @temp_source_path ||= File.expand_path "./source-temp", root
    end

  end
end