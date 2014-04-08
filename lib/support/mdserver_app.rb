require 'sinatra/base'
require 'kramdown'
require 'coderay'
require 'coderay_bash'
require 'support'

module Support
  class MDServer < Sinatra::Base
    configure do
      set :file_root,  CONFIG[:browser][:file_root]
      set :nav_links,  CONFIG[:browser][:nav_links]
      set :assets,     CONFIG[:browser][:assets]
      settings.views = File.expand_path(CONFIG[:browser][:views])
    end

    helpers do
      def resolve_path p
        candidate = settings.file_root + p 
        if File.exists? candidate
          candidate
        else
          false
        end
      end

      def path
        ENV['APP_ROOT']
      end

      def nav_links
        settings.nav_links
      end

      def assets
        settings.assets
      end

      def get_title p, suffix = '.md'
        title = File.basename(p, suffix)
        title = '/' if title === settings.file_root
        title
      end

      def git_base p = nil
        p = File.join(CONFIG[:browser][:file_root], params['captures'].first.chomp('/')) if p.nil?
        if p === CONFIG[:browser][:file_root] or p === '.' or p.length === 0
          false
        elsif File.directory? p
          candidate = File.join(p, '.git')
          if File.exists? candidate
            "http://#{request.host}#{request.script_name}#{p[CONFIG[:browser][:file_root].length, p.length]}"
          else
            git_base File.dirname(p)
          end
        else
          git_base File.dirname(p)
        end
      end

      def get_breadcrumbs p
        parts = p.split('/').map {|e| e === '' ? nil : e }.compact
        if parts.length > 0
          last = parts.pop
          crumbs = ["<a href=\"#{path}\">Home</a>"]
          partial = []
          parts.each do |part|
            partial << part
            crumbs << "<a href=\"#{path}#{partial.join('/')}/\">#{part}</a>"
          end
          crumbs << last
        else
          crumbs = ['Home']
        end
        crumbs.join( " / ")
      end

      def directory file, p
        erb :directory, {locals: { entries: Dir.entries(file).map do |ent|
          case ent
          when '.', '.git'
            nil
          when '..'
            if File.basename(file) === settings.file_root
              nil
            else
              {name: ent, path: File.dirname(p) + '/'}
            end
          else
            if File.directory? File.join(file, ent)
              {name: ent, path: p + ent + '/'}
            else
              {name: ent, path: p + ent}
            end
          end
        end.compact }, layout: false}
      end

      def kramdown file
        Kramdown::Document.new(IO.read(file)).to_html
      end
    end
    get %r{^(.*\.md)$} do
      file = resolve_path params['captures'].first
      if file
        erb kramdown(file), locals: {
          title: get_title(file),
          breadcrumbs: get_breadcrumbs(params['captures'].first)
        }
      else
        pass
      end
    end
    get %r{^(.*/)$} do
      file = resolve_path params['captures'].first
      if file and File.directory?(file)
        if File.exists? file + "index.md"
          redirect to(params['captures'].first + "index.md")
        else
          erb directory(file, path.chomp('/') + params['captures'].first), locals: {
            title: get_title(file),
            breadcrumbs: get_breadcrumbs(params['captures'].first)
          }
       end
      else
        pass
      end
    end
    get %r{^(.*?(\.[^./]+)?)$} do
      file = resolve_path params['captures'].first
      if file
        if File.directory? file
          redirect to(params['captures'].first + "/")
        else
          if TYPES.has_key? params['captures'].last
            content_type TYPES[params['captures'].last]
          end
          IO.read(file)
        end
      else
        pass
      end
    end
  end
end
