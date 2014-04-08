require 'support'

module Support
  class Env
    def initialize app
      @app = app
    end
    def call env
      if CONFIG.has_key? :rack and CONFIG[:rack].has_key? :mount
        env['SCRIPT_NAME'] = CONFIG[:rack][:mount] + env['SCRIPT_NAME']
        status, headers, body = *@app.call(env)
        if status === 301 or status === 302
          if headers.has_key? 'Location'
            headers['Location'].sub!(%r{#{CONFIG[:rack][:mount]}/}, '/')
          end
        end
        [status, headers, body]
      else
        @app.call(env)
      end
    end
  end
end
