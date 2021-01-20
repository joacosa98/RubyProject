require_relative '../lib/server'
require_relative '../lib/client'
require 'yaml'

describe Server do
    before(:all) do
        config = YAML.load_file("spec/testing_config.yml") #reads config file
        server = config["server"]
        port = config["port"]
        checkTime = config["checkTime"]

        @s = Server.new(server, port, checkTime)
        @t1 = Thread.new { 
            @s.run()
        }
        sleep(1) #waits for server to be running
        @c = Client.new(server, port)
        end 
    after(:all) do
        Thread.kill(@t1) #kills thread before kill server to avoid IOERROR exception
        @s.kill_server() # must close the socket for next test
        sleep(1)
    end

    context "valid comand gets" do
        it "should retrieve the info of one key" do
            #ADD ITEM
            @c.set_socket()
            instr = "add key 1231 1000 5\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #GETS ITEM
            @c.set_socket()
            instr = "gets key\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server

            #get cas_unique
            savedD = @s.get_data('key')
            cas_unique = savedD.cas_unique

            #CHECK RESULTS
            expect(@c.socket.gets.chop).to eq "VALUE key 1231 5 #{cas_unique}" 
            expect(@c.socket.gets.chop).to eq 'value'
            expect(@c.socket.gets.chop).to eq 'END'            
        end
    

        it "should retrieve the info of many keys" do
            #ADD ITEM
            @c.set_socket()
            instr = "add key1 1245331 500 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value1\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server

             #ADD ITEM
             @c.set_socket()
             instr = "add key2 121331 450 6\n"
             sleep(0.5)
             @c.send_data(instr) #sends instruction to the server
             value = "value2\n"
             sleep(0.5)
             @c.send_data(value) #sends value to the server
             expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server

            #get cas_unique
            savedD = @s.get_data('key')
            cas_unique = savedD.cas_unique
            savedD = @s.get_data('key1')
            cas_unique1 = savedD.cas_unique
            savedD = @s.get_data('key2')
            cas_unique2 = savedD.cas_unique
            
             
            #GETS ITEM
            @c.set_socket()
            instr = "gets key key1 key2\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server


            #CHECK RESULTS            
            expect(@c.socket.gets.chop).to eq "VALUE key 1231 5 #{cas_unique}" #first key
            expect(@c.socket.gets.chop).to eq 'value'

            expect(@c.socket.gets.chop).to eq "VALUE key1 1245331 6 #{cas_unique1}" #second key
            expect(@c.socket.gets.chop).to eq 'value1'

            expect(@c.socket.gets.chop).to eq "VALUE key2 121331 6 #{cas_unique2}" #third key
            expect(@c.socket.gets.chop).to eq 'value2'

            expect(@c.socket.gets.chop).to eq 'END'

        end

        it "should only retrieve the info of the keys that exist" do
            #GETS ITEM
            @c.set_socket()
            instr = "gets key key12 key2\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server

            #get cas_unique
            savedD = @s.get_data('key')
            cas_unique = savedD.cas_unique
            savedD = @s.get_data('key2')
            cas_unique2 = savedD.cas_unique
            
            #CHECK RESULTS           
            expect(@c.socket.gets.chop).to eq "VALUE key 1231 5 #{cas_unique}" #first key
            expect(@c.socket.gets.chop).to eq 'value'


            expect(@c.socket.gets.chop).to eq "VALUE key2 121331 6 #{cas_unique2}" #third key
            expect(@c.socket.gets.chop).to eq 'value2'

            expect(@c.socket.gets.chop).to eq 'END'

        end

        it "should not retrieve because the key expired" do
            #ADD ITEM
            @c.set_socket()
            instr = "add key3 121235331 3 5\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            sleep(4)#waits for the key to expire
            
            #GETS ITEM
            @c.set_socket()
            instr = "gets key3\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            
            #CHECK RESULTS
            expect(@c.socket.gets.chop).to eq 'END'

        end

    end

   context "invalid instruction format" do
        it "should fail for no keys given" do
            #GETS ITEM
            @c.set_socket()
            instr = "gets\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
   end
 end