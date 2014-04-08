ENV['HOME'] ||= ENV['PWD']
require 'yard'

# I want yard to operate relative to a base
# context rather than assume it runs at the doc root.
module YARD
  module Server
    module Commands
      class StaticFileCommand
        def run
          assets_template = Templates::Engine.template(:default, :fulldoc, :html)
          path = File.cleanpath(request.path_info).gsub(%r{^(../)+}, '')

          file = nil
          ([adapter.document_root] + STATIC_PATHS.reverse).compact.each do |path_prefix|
            file = File.join(path_prefix, path)
            break if File.exist?(file)
            file = nil
          end

          # Search in default/fulldoc/html template if nothing in static asset paths
          file ||= assets_template.find_file(path)

          if file
            ext = "." + (request.path_info[/\.(\w+)$/, 1] || "html")
            headers['Content-Type'] = mime_type(ext, DefaultMimeTypes)
            self.body = File.read(file)
            return
          end

          favicon?
          self.status = 404
        end
      end
    end
    class Router
      def route path = request.path_info
        path = path.gsub(%r{//+}, '/').gsub(%r{^/|/$}, '')
        return route_index if path.empty? || path == docs_prefix
        case path
        when /^(#{docs_prefix}|#{list_prefix}|#{search_prefix})(\/.*|$)/
          prefix = $1
          paths = $2.gsub(%r{^/|/$}, '').split('/')
          library, paths = *parse_library_from_path(paths)
          return unless library
          return case prefix
          when docs_prefix;   route_docs(library, paths)
          when list_prefix;   route_list(library, paths)
          when search_prefix; route_search(library, paths)
          end
        end
        nil
      end
    end
  end
end
