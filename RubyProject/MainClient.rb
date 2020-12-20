require_relative 'lib/Client'

puts "Which server do you wish to connect to?"
server = $stdin.gets.chop

puts "Which port do you wish to connect to?"
port = $stdin.gets.to_i

client = Client.new(server, port)
client.connect

