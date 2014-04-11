require 'support'

module Support
  class Env
    def initialize app
      @app = app
    end

    def call env
      if rewrite?
        env['SCRIPT_NAME'] = forward env['SCRIPT_NAME']
        status, headers, body = *@app.call(env)
        if status === 301 or status === 302
          if headers.has_key? 'Location'
            headers['Location'] = reverse headers['Location']
          end
        end
        [status, headers, body]
      else
        @app.call(env)
      end
    end

    private
    def rewrite?
      ENV.has_key? 'APP_ROOT' and ENV.has_key? 'APP_CONTEXT'
    end

    def root
      (ENV['APP_ROOT'] || '').chomp('/')
    end

    def context
      (ENV['APP_CONTEXT'] || '').chomp('/')
    end

    def forward path
      if path.index(context) === 0
        root + path[context.length, path.length]
      else
        path
      end
    end

    def reverse path
      if root.length > 0
        matches = %r{([a-z]*://[^/]*)(/.*|$)}.match(path)
        if matches[2].index(root) === 0
          matches[1] + matches[2].sub(root, context + additional)
        else
          path
        end
      else
        path
      end
    end
  end
end
