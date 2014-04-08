libdir = File.expand_path('lib', File.dirname(__FILE__))
$LOAD_PATH << libdir unless $LOAD_PATH.include? libdir

require 'support'
require 'support/env'
require 'support/grack_middleware'
require 'support/geminabox_app'
require 'support/mdserver_app'
require 'support/yard'
require 'support/yard_app'

use Rack::Lock
use Support::Env

map '/' do
  use Support::GrackMiddleware
  run Support::MDServer
end

map '/gem' do
  run Support::GeminaboxApp.new
end

map '/yard' do
  run Support::YardApp.new
end
