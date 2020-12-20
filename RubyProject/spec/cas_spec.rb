require_relative '../lib/Server'
require_relative '../lib/Client'
require 'yaml'

describe Server do
    before(:all) do
        config = YAML.load(File.read("spec/Config.yml")) #reads config file 
        server = config["server"].to_s
        port = config["port"].to_i
        checkSize = config["checkSize"].to_i
        checkTime = config["checkTime"].to_i

        @s = Server.new(server, port, checkSize, checkTime)
        @t1 = Thread.new { 
            @s.run()
        }
        sleep(1) #waits for server to be running
        @c = Client.new(server, port)
        end 
    after(:all) do
        Thread.kill(@t1) #kills thread before kill server to avoid IOERROR exception
        @s.killServer() # must close the socket for next test
        sleep(1)
    end

    context "valid comand cas" do

        it "should update the item" do
            #ADD ITEM
            @c.setSocket()
            instr = "add key 1231 1000 5\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "Value\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #get casUnique
            savedD = @s.getData('key')
            casUnique = savedD.casUnique

            #CAS ITEM
            @c.setSocket()
            instr = "cas key 10031 500 8 " +casUnique.to_s+ "\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "casValue\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #CHECK RESULTS
            savedD = @s.getData('key')
            expect(savedD.size).to eq 8
            expect(savedD.value).to eq 'casValue'
            expect(savedD.flag).to eq 10031

            savedE = @s.getExp('key')
            expect(savedE.expiration).to eq 500

        end

        it "Should not update the item because the key expired" do
            #ADD ITEM
            @c.setSocket()
            instr = "add key2 1231 3 6\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            sleep(4) # wait until it expires

            #get casUnique
            savedD = @s.getData('key2')
            casUnique = savedD.casUnique

            #CAS ITEM
            @c.setSocket()
            instr = "cas key2 10031 500 8 " +casUnique.to_s+ "\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "casValue\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'NOT_FOUND' #gets response from the server

        end

        it "Should not update the item because the key does not exists" do
            #CAS ITEM
            @c.setSocket()
            instr = "cas key2 10031 500 8 871623\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "casValue\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'NOT_FOUND' #gets response from the server

        end

        it "Should not update the item because the casUnique does not match" do
            #ADD ITEM
            @c.setSocket()
            instr = "add key3 1231 1000 5\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "Value\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #get casUnique
            savedD = @s.getData('key3')
            casUnique = savedD.casUnique

            #SET ITEM TO CHANGE THE CASUNIQUE VALUE
            @c.setSocket()
            instr = "set key3 12301 1000 5\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "Value\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server

            #CAS ITEM
            @c.setSocket()
            instr = "cas key3 10031 500 8 " +casUnique.to_s+ "\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "casValue\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'EXISTS' #gets response from the server

        end
    end

    context "invalid instruction format" do
        it "Should fail because of invalid length instruction" do
            #CAS ITEM WITH WRONG LENGTH
            @c.setSocket()
            instr = "cas key2 3234123 100 6\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "value3\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of flag not numeric" do
            #CAS WITH FLAG NOT NUMERIC
            @c.setSocket()
            instr = "cas key2 flag 100 6 2342341\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of expiration not numeric" do
            #CAS WITH EXPIRATION NOT NUMERIC
            @c.setSocket()
            instr = "cas key2 1231 expiration 6 2342341\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of size not numeric" do
            #CAS WITH SIZE NOT NUMERIC
            @c.setSocket()
            instr = "cas key2 1231 1000 size 2342341\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end    
    end
 end