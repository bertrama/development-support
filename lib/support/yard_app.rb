ENV['HOME'] = ENV['PWD']
require 'support'
require 'bundler'
require 'rubygems'
require 'yard'
require 'yard/server/adapter'
require 'yard/server/rack_adapter'
require 'yard/templates/engine'
require 'yard/templates/erb_cache'
require 'yard/templates/helpers/base_helper'

module Support
  class YardApp
    def initialize
      libraries = {}
      Gem::Specification.each do |spec|
        libraries[spec.name] ||= []
        libraries[spec.name] |= [YARD::Server::LibraryVersion.new(spec.name, spec.version.to_s, nil, :gem)]
      end
      YARD::Server::RackAdapter.setup
      @yard = YARD::Server::RackAdapter.new libraries, {}, {}
      YARD::Templates::Engine.register_template_path File.expand_path(CONFIG[:yard][:templates])
      YARD::Templates::Template.extra_includes << Support::YARDHelpers
    end

    def call env
      @yard.call(env)
    end
  end

  module YARDHelpers
    def url_for       *args ; router.request.script_name + super end
    def url_for_file  *args ; router.request.script_name + super end
    def url_for_list  *args ; router.request.script_name + super end
    def url_for_index *args ; router.request.script_name + super end
    def url_for_frameset *args
      router.request.script_name + super.sub(%r{#{router.request.path}}, '')
    end
  end
end
