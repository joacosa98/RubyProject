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

    context "valid comand append" do

        it "should add the item and then append the given value" do
            #ADD ITEM
            @c.set_socket()
            instr = "add key 1231 1000 5\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #APPEND ITEM
            @c.set_socket()
            instr = "append key 1031 5000 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "Append\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server

            #CHECK RESULTS
            savedD = @s.get_data('key')
            expect(savedD.size).to eq 11
            expect(savedD.value).to eq 'valueAppend'
            expect(savedD.flag).to eq 1231

            savedE = @s.get_exp('key')
            expect(savedE.expiration).to eq 1000

        end

        it "Should not append the item because the key expired" do
            #ADD ITEM
            @c.set_socket()
            instr = "add key2 1231 3 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            sleep(4) # wait until it expires

            #APPEND ITEM
            @c.set_socket()
            instr = "append key2 1231 1003 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "Append\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'NOT_STORED' #gets response from the server

        end

        it "Should not append the item because the key does not exists" do
            #APPEND ITEM
            @c.set_socket()
            instr = "append key4 1231 100 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'NOT_STORED' #gets response from the server

        end
    end

    context "invalid instruction format" do
        it "Should fail because of invalid length instruction" do
            #APPEND ITEM WITH WRONG LENGTH
            @c.set_socket()
            instr = "append key3 1231234 100\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value3\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of flag not numeric" do
            #APPEND WITH FLAG NOT NUMERIC
            @c.set_socket()
            instr = "append key2 flag 100 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of expiration not numeric" do
            #APPEND WITH EXPIRATION NOT NUMERIC
            @c.set_socket()
            instr = "append key2 1231 expiration 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of size not numeric" do
            #APPEND WITH SIZE NOT NUMERIC
            @c.set_socket()
            instr = "append key2 1231 1000 size\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end    
    end
 end