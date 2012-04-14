lib_path = File.expand_path(File.dirname(__FILE__)) + "/../lib/"
$LOAD_PATH << lib_path unless $LOAD_PATH.include? lib_path

require 'okey'
require 'daemons'
config = {
  :host      => '0.0.0.0',
  :ws_port   => 8080,
  :http_port => 3000,
  :env       => "production"
}

Daemons.run_proc('okey-daemon') do
  Okey::Server.start(config)
end