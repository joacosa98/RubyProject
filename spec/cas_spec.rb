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

    context "valid comand cas" do

        it "should update the item" do
            #ADD ITEM
            @c.set_socket()
            instr = "add key 1231 1000 5\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "Value\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #get cas_unique
            savedD = @s.get_data('key')
            cas_unique = savedD.cas_unique

            #CAS ITEM
            @c.set_socket()
            instr = "cas key 10031 500 8 #{cas_unique}\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "casValue\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #CHECK RESULTS
            savedD = @s.get_data('key')
            expect(savedD.size).to eq 8
            expect(savedD.value).to eq 'casValue'
            expect(savedD.flag).to eq 10031

            savedE = @s.get_exp('key')
            expect(savedE.expiration).to eq 500

        end

        it "Should not update the item because the key expired" do
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

            #get cas_unique
            savedD = @s.get_data('key2')
            cas_unique = savedD.cas_unique

            #CAS ITEM
            @c.set_socket()
            instr = "cas key2 10031 500 8 #{cas_unique}\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "casValue\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'NOT_FOUND' #gets response from the server

        end

        it "Should not update the item because the key does not exists" do
            #CAS ITEM
            @c.set_socket()
            instr = "cas key2 10031 500 8 871623\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "casValue\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'NOT_FOUND' #gets response from the server

        end

        it "Should not update the item because the cas_unique does not match" do
            #ADD ITEM
            @c.set_socket()
            instr = "add key3 1231 1000 5\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "Value\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #get cas_unique
            savedD = @s.get_data('key3')
            cas_unique = savedD.cas_unique

            #SET ITEM TO CHANGE THE CASUNIQUE VALUE
            @c.set_socket()
            instr = "set key3 12301 1000 5\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "Value\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server

            #CAS ITEM
            @c.set_socket()
            instr = "cas key3 10031 500 8 #{cas_unique}\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "casValue\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'EXISTS' #gets response from the server

        end
    end

    context "invalid instruction format" do
        it "Should fail because of invalid length instruction" do
            #CAS ITEM WITH WRONG LENGTH
            @c.set_socket()
            instr = "cas key2 3234123 100 6\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value3\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of flag not numeric" do
            #CAS WITH FLAG NOT NUMERIC
            @c.set_socket()
            instr = "cas key2 flag 100 6 2342341\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of expiration not numeric" do
            #CAS WITH EXPIRATION NOT NUMERIC
            @c.set_socket()
            instr = "cas key2 1231 expiration 6 2342341\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of size not numeric" do
            #CAS WITH SIZE NOT NUMERIC
            @c.set_socket()
            instr = "cas key2 1231 1000 size 2342341\n"
            sleep(0.5)
            @c.send_data(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.send_data(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end    
    end
 end