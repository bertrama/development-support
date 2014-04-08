require 'yaml'

module Support
  CONFIG = YAML.load_file 'config.yml'
  TYPES  = {
    '.txt'  => 'text/plain',
    '.css'  => 'text/css',
    '.js'   => 'text/javascript',
    '.eot'  => 'application/vnd.ms-fontobject',
    '.ttf'  => 'application/octet-stream',
    '.woff' => 'application/font-woff',
  }
end
