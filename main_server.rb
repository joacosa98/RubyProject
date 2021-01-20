require_relative 'lib/server'
require 'yaml'

config = YAML.load_file("config.yml") #reads config file 
server = config["server"]
port = config["port"]
checkTime = config["checkTime"]

s = Server.new(server, port, checkTime)
s.start_server()