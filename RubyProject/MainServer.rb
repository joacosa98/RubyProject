require_relative 'lib/Server'
require 'yaml'

config = YAML.load(File.read("Config.yml")) #reads config file 
server = config["server"].to_s
port = config["port"].to_i
checkSize = config["checkSize"].to_i
checkTime = config["checkTime"].to_i

s = Server.new(server, port, checkSize, checkTime)
s.startServer()