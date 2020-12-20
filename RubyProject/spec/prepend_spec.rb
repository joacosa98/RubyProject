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

    context "valid comand prepend" do

        it "should prepend the item and then prepend the given value" do
            #ADD ITEM
            @c.setSocket()
            instr = "add key 1231 1000 5\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "Value\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #PREPEND ITEM
            @c.setSocket()
            instr = "prepend key 1031 5000 7\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "prepend\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'STORED' #gets response from the server
            
            #CHECK RESULTS
            savedD = @s.getData('key')
            expect(savedD.size).to eq 12
            expect(savedD.value).to eq 'prependValue'
            expect(savedD.flag).to eq 1231

            savedE = @s.getExp('key')
            expect(savedE.expiration).to eq 1000

        end

        it "Should not prepend the item because the key expired" do
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

            #PREPEND ITEM
            @c.setSocket()
            instr = "prepend key2 1231 1003 6\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "Append\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'NOT_STORED' #gets response from the server

        end

        it "Should not prepend the item because the key does not exists" do
            #PREPEND ITEM
            @c.setSocket()
            instr = "prepend key4 1231 100 6\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'NOT_STORED' #gets response from the server

        end
    end

    context "invalid instruction format" do
        it "Should fail because of invalid length instruction" do
            #PREPEND ITEM WITH WRONG LENGTH
            @c.setSocket()
            instr = "prepend key3 1212312 100\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "value3\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of flag not numeric" do
            #PREPEND WITH FLAG NOT NUMERIC
            @c.setSocket()
            instr = "prepend key2 flag 100 6\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of expiration not numeric" do
            #PREPEND WITH EXPIRATION NOT NUMERIC
            @c.setSocket()
            instr = "prepend key2 1231 expiration 6\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end
        
        it "Should fail because of size not numeric" do
            #PREPEND WITH SIZE NOT NUMERIC
            @c.setSocket()
            instr = "prepend key2 1231 1000 size\n"
            sleep(0.5)
            @c.sendData(instr) #sends instruction to the server
            value = "value2\n"
            sleep(0.5)
            @c.sendData(value) #sends value to the server
            expect(@c.socket.gets.chop).to eq 'CLIENT_ERROR<wrong format instruction>' #gets response from the server
        end    
    end
 end