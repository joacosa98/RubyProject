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

    context "valid comand set" do

        it "should set both items" do
            #SET FIRST ITEM
            @c.set_socket()
            instr = "set key 1231 1000 5\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #SET SECOND ITEM
            @c.set_socket()
            instr = "set key1 1031 5000 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value1\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #CHECK RESULTS
            savedD = @s.get_data('key')
            expect(savedD.size).to eq 5
            expect(savedD.value).to eq 'value'
            expect(savedD.flag).to eq 1231

            savedD = @s.get_data('key1')
            expect(savedD.size).to eq 6
            expect(savedD.value).to eq 'value1'
            expect(savedD.flag).to eq 1031

            savedE = @s.get_exp('key')
            expect(savedE.expiration).to eq 1000

            savedE = @s.get_exp('key1')
            expect(savedE.expiration).to eq 5000
        end

        it "Should add the item despite that the same key already exists" do
             #SET EXISTING ITEM
             @c.set_socket()
             instr = "set key1 102131 1000 9\n"
             sleep(0.5)
             @c.send_data(instr) #sends instruction to the server
             value = "setValue1\n"
             sleep(0.5)
             @c.send_data(value) #sends value to the server
             expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
             
             #CHECK RESULTS
             savedD = @s.get_data('key1')
             expect(savedD.size).to eq 9
             expect(savedD.value).to eq 'setValue1'
             expect(savedD.flag).to eq 102131

            savedE = @s.get_exp('key')
            expect(savedE.expiration).to eq 1000

        end
    end

    context "invalid instruction format" do
        it "Should fail because of invalid length instruction" do
            #SET ITEM WITH WRONG LENGTH
            @c.set_socket()
            instr = "set key3 451123 100\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value3\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of flag not numeric" do
            #SET WITH FLAG NOT NUMERIC
            @c.set_socket()
            instr = "set key2 flag 100 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of expiration not numeric" do
            #SET WITH EXPIRATION NOT NUMERIC
            @c.set_socket()
            instr = "set key2 1231 expiration 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of size not numeric" do
            #SET WITH SIZE NOT NUMERIC
            @c.set_socket()
            instr = "set key2 1231 1000 size\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end    
    end
 end