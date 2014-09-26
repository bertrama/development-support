require 'sinatra/base'
require 'kramdown'
require 'coderay'
require 'coderay_bash'
require 'support'

ENV['HOME'] = Dir.pwd
require 'yard'
require 'yard/cli/command_parser'

module Support
  class MDServer < Sinatra::Base
    def self.gemfile_thread
      return nil
      #Thread.new do ; loop do
      #  Dir.glob(File.join(CONFIG[:gemserver][:data], '**/*.gem')) do |gem|
      #    @@gemfiles[File.basename(gem)] = gem
      #  end
      #end ; end
    end
    def self.gemspec_thread
      Thread.new do ; loop do
        if @@gemspecs.empty?
          sleep 10
        else
          sleep 30
          spec = @@gemspecs.shift
          begin
            base = Dir.pwd
            name = File.basename(spec.spec_name, '.gemspec')
            output = File.join(base, CONFIG[:browser][:yard_out], name)
            yardoc = File.join(base, CONFIG[:browser][:yardoc], name)
            Dir.chdir spec.full_gem_path do |dir|
              YARD::CLI::CommandParser.run 'doc',
                '-o', output,
                '-c', yardoc,
                '-b', yardoc,
                '--single-db'
            end
          rescue Exception => e
          end
        end
      end ; end
    end

    configure do
      set :file_root,  CONFIG[:browser][:file_root]
      set :nav_links,  CONFIG[:browser][:nav_links]
      set :assets,     CONFIG[:browser][:assets]
      set :root_redirect, CONFIG[:browser][:root_redirect]
      settings.views = File.expand_path(CONFIG[:browser][:views])
      @@gemspecs = []
      @@gemspec_thread = gemspec_thread
      @@gemfiles = {}
      @@gemfile_thread = gemfile_thread
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
        if params['captures'].nil?
          false
        else
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
            elsif File.dirname(p) === '/'
              {name: ent, path: File.dirname(p)}
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
        end.compact.sort {|a,b| a[:path] <=> b[:path]}}, layout: false}
      end

      def kramdown file
        Kramdown::Document.new(IO.read(file)).to_html
      end
    end

    get '/' do
      redirect to(settings.root_redirect)
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
        elsif File.exists? file + "index.html"
          redirect to(params['captures'].first + 'index.html')
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
    get '/yard/admin' do
      admin = <<-EOF
<div class="well well-sm">
  <a href="#{url('yard/status')}">Status</a>
</div>
<div class="well well-sm">
  <a href="#{url('yard/clear')}">Clear</a>
</div>
<div class="well well-sm">
  <a href="#{url('yard/regen')}">Regen</a>
</div>
      EOF
      erb admin, locals: {
        title: 'Yard Admin',
        breadcrumbs: false
      }
      
    end
    get '/yard/clear' do
      @@gemspecs = []
      erb "Yard queue cleared", locals: {
        title: 'Yard Status',
        breadcrumbs: '<a href="/">Home</a> / Yard Clear'
      }
    end
    get '/yard/status' do
      erb "<div class=\"well\">Status: #{@@gemspecs.length} specs to index.</div>", locals: {
        title: 'Yard Status',
        breadcrumbs: '<a href="/">Home</a> / Yard Status'
      }
    end
    get '/yard/regen' do
      tmp = Gem.paths
      Gem.use_paths tmp.home, tmp.path | Gem.default_path
      Gem::Specification.all = nil
      Gem::Specification.each do |spec|
        @@gemspecs << spec
      end
      Gem.use_paths tmp.home, tmp.path
      Gem::Specification.reset
      erb 'Regenerating Yard Documents', locals: {
        title: 'Yard Regen',
        breadcrumbs: 'Home'
      }
    end
  end
end
