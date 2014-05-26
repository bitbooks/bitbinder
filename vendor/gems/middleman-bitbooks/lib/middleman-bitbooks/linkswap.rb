module Middleman
  module Bitbooks

    # Extension namespace
    # @todo: Retest this after gem reconfiguration.
    class Linkswap < ::Middleman::Extension

      def initialize(app, options_hash={}, &block)
        # Call super to build options from the options_hash
        super

        # Swap the links the links after build.
        app.after_build do |builder|

          #binding.remote_pry
          # Looping the files and directories. We just want to do a regex
          # substitution on the files, pointing any .md links to the converted
          # .html files.
          #
          # @todo: make this method support directory indexes. It doesn't now, but
          #        we could grab that setting, check it, and alter the code to
          #        accomodate, if we wanted to. Low priority because this isn't
          #        being released as open source since it's pretty bitbooks
          #        specific.
          # @todo: this currently does substitutions on CSS, JS, and images files,
          #        which is ok, since there aren't any matches, but ultimately we
          #        want to exclude them, like we do for navtree.
          Dir.glob("build/**/*").each do |path|

            if !File.directory?(path)
              # Regex Notes: Matches on: href="*.md" and href="*.markdown"
              #              Captures: ".md" and ".markdown"
              # I can count on there being "" (double quotes) because the html is
              # generated from markdown
              regex = /(?:href=")(?:.*)(.md|.markdown)(?:")/

              # I need to reproduce the behavior of Thor's gsub_file, (which code can
              # be found here: http://rubydoc.info/github/wycats/thor/master/Thor/Actions:gsub_file)
              # because it doesn't support regex matches inside a gsub block. See more
              # information here: https://github.com/erikhuda/thor/issues/207
              next unless builder.behavior == :invoke
              path = File.expand_path(path, builder.destination_root)
              builder.say_status :gsub, builder.relative_to_original_destination_root(path)
              content = File.binread(path)
              content.gsub!(regex) do |match|
                match.gsub($1, ".html")
              end
              File.open(path, 'wb') { |file| file.write(content) }

            end
          end
        end
      end

    end
  end
end