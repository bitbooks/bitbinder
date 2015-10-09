# This is the main file. A simple Sinatra app that exposes endpoints for triggering middleman builds.

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
      IO.write(book_data_path, YAML::dump(@datahash))

      perform_build if github.scopes.include?("public_repo") || github.scopes.include?("repo")
      status 200
    end

    post '/copy' do
      @datahash = JSON.parse(params[:data])
      encryptedtoken = @datahash.delete("token")
      @token = Encryptor.decrypt(Base64.decode64(encryptedtoken), :key => SECRET_KEY)

      repo = clone_and_push if github.scopes.include?("public_repo") || github.scopes.include?("repo")

      # Return information about the repo we created via json.
      content_type :json
      repo.to_hash.to_json
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
        FileUtils.rm_rf book_data_path
        FileUtils.rm_rf navtree_data_path
      end
    end

    def pull_source
      # I'd prefer to clone over pull because it seems faster, but we'll settle for this.
      FileUtils.cp_r source_path, temp_source_path
      Dir.chdir temp_source_path
      Open3.capture2 "git", "init"
      Open3.capture2 "git", "remote", "add", "downstream", "#{destination.scheme}://#{destination.host}/#{full_name}.git"
      Open3.capture2 "git", "pull", "--quiet", "downstream", "master"
    end

    def middleman_build
      Dir.chdir root
      Open3.capture2 "bundle", "exec", "middleman", "build"
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
        # (prevents creating a new destination repo when one already exists)
        # This is a double-check because it's already checked when the name is chosen.
        # However, this check keeps the job idempotent... which is important.
        # @todo: This is crude error reporting. Determine the best way to do this in for production.
        Open3.capture2 "echo", "Could not copy the repo, because the destination repository already exists."
        halt 400
      else
        FileUtils.rm_rf repo_path # Not sure why I need this, but it existed in copy-to.
        Dir.chdir root
        begin
          options = { :description => "An online book.", :homepage => link_to_book }
          repo_info = github.create_repository full_name.split('/')[1], options # Create empty repo on github.
          Open3.capture2 "git", "clone", "--quiet", "#{destination.scheme}://#{destination.host}/bitbooks/starter-book.git", repo_path
          Dir.chdir repo_path
          Open3.capture2 "git", "remote", "add", "downstream", destination_remote
          Open3.capture2 "git", "push", "downstream", "master"
        ensure
          Dir.chdir root # We need to move out of the folder we are deleting or we'll get errors trying to use pry.
          FileUtils.rm_rf repo_path
        end
        return repo_info if defined?(repo_info) != nil
      end
    end

    def repo_exists?
      if @datahash['repo_id'] != nil
        return github.repository? @datahash['repo_id']
      elsif @datahash['gh_full_name'] != nil
        return github.repository? @datahash['gh_full_name']
      else
        # Could not determine if repo exists. This shouldn't ever happen.
        return nil
      end
    end

    def destination
      URI.parse Octokit.web_endpoint
    end

    def destination_remote
      "#{destination.scheme}://#{@token}:x-oauth-basic@#{destination.host}/#{full_name}.git"
    end

    # Prevent malformed URL from being used. @todo: we may be able to delete this.
    def link_to_book
      # If a custom domain hasn't been specified, return the default github url.
      if @datahash['domain'].nil? || @datahash['domain'].empty?
        ''
      else
        @datahash['domain']
      end
    end

    # This is the main function for interfacing with the Github API. Unfortunately,
    # I had to make it more verbose in order to handle unauthorize errors (using
    # validate_credentials()... the rescue block just didn't seem to work). Maybe
    # some day I can get it back to the simplicity the older one.
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

    def full_name
      if @datahash['repo_id'] != nil
        return github.repository(@datahash['repo_id']).full_name
      elsif @datahash['gh_full_name'] != nil
        return @datahash['gh_full_name']
      else
        # Could not determine the full_name. This shouldn't ever happen.
        nil
      end
    end

    # For copy-to
    def repo_path
      @repo_path ||= File.expand_path "./#{SecureRandom.hex}", root
    end

    def build_path
      @build_path ||= File.expand_path "./build", root
    end

    def book_data_path
      @book_data_path ||= File.expand_path "./data/book.yml", root
    end

    def navtree_data_path
      @navtree_data_path ||= File.expand_path "./data/tree.yml", root
    end

    def source_path
      @source_path ||= File.expand_path "./source", root
    end

    def temp_source_path
      @temp_source_path ||= File.expand_path "./source-temp", root
    end

  end
end
