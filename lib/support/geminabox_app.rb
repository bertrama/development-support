require 'geminabox'
require 'support'

module Support
  class GeminaboxApp
    def initialize
      Geminabox.data = CONFIG[:geminabox][:data]
      @geminabox = Geminabox::Server
    end

    def call env
      @geminabox.call(env)
    end
  end
end
