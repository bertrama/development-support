require 'grack/server'
require 'support'

module Support
  class GrackMiddleware
    def initialize app
      @app = app
      @grack = Grack::Server.new CONFIG[:grack]
    end

    def call env
      status, headers, response = *@grack.call(env)
      if status != 200
        @app.call(env)
      else
        [status, headers, response]
      end
    end
  end
end
