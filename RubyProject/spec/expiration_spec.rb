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
            @s.purgeKeys()
        }
    end 
    after(:all) do
        Thread.kill(@t1) #kills thread before kill server to avoid IOERROR exception
        @s.killServer() # must close the socket for next test
        sleep(1)
    end

    it "should delete only expired keys" do
        #ADD ITEMS
        i = 1
        exp = 0.5
        while i<6 do
            exp = exp * 10

            @s.set(nil, "key" +i.to_s, 87123, exp, 5, "value", true)
            i = i+1
        end
        #ADD ITEMS WITH UNIX TIME
            @s.set(nil, "keyUnix1", 8712123, 259200055, 5, "value", true) #1978-03-19 21:00:55 -0300

            @s.set(nil, "keyUnix2", 8712123, 1692000554, 5, "value", true) #2023-08-14 05:09:14 -0300

            sleep(10) #waits for key1 to expire
            expect(@s.getData("key1")).to be_nil
            expect(@s.getData("key2")).not_to be_nil
            expect(@s.getData("key3")).not_to be_nil
            expect(@s.getData("key4")).not_to be_nil
            expect(@s.getData("key5")).not_to be_nil
            expect(@s.getData("keyUnix1")).to be_nil
            expect(@s.getData("keyUnix2")).not_to be_nil
            
    end

    it "should not delete any key" do
        #ADD ITEMS
        i = 1
        exp = 0.5
        while i<6 do
            @s.set(nil, "key" +i.to_s, 87123, 10000, 5, "value", true)
            i = i+1
        end
 
        #ADD ITEMS WITH INFINIT TIME
            @s.set(nil, "infKey1", 8712123, 0, 5, "value", true) #never expires
            @s.set(nil, "infKey2", 8712123, 0, 5, "value", true) #never expires

            expect(@s.getData("key1")).not_to be_nil
            expect(@s.getData("key2")).not_to be_nil
            expect(@s.getData("key3")).not_to be_nil
            expect(@s.getData("key4")).not_to be_nil
            expect(@s.getData("key5")).not_to be_nil
            expect(@s.getData("infKey1")).not_to be_nil
            expect(@s.getData("infKey2")).not_to be_nil
            
    end
        
    it "should delete all keys" do
        #ADD ITEMS
        i = 1
        while i<6 do
            @s.set(nil, "key" +i.to_s, 87123, -1, i, "value", true)
            i = i+1
        end
        
        #ADD ITEMS WITH INFINIT TIME
            @s.set(nil, "expKey1", 8712123, -1, 5, "value", true) # expires immediately
            @s.set(nil, "expKey2", 8712123, 592000550, 5, "value", true) #1988-10-04 17:35:50 -0300

            sleep(10)
            expect(@s.getData("key1")).to be_nil
            expect(@s.getData("key2")).to be_nil
            expect(@s.getData("key3")).to be_nil
            expect(@s.getData("key4")).to be_nil
            expect(@s.getData("key5")).to be_nil
            expect(@s.getData("expKey1")).to be_nil
            expect(@s.getData("expKey2")).to be_nil
            
    end
end
