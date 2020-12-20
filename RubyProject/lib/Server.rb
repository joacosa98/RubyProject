require 'socket'
require_relative 'SavedData'
require_relative 'DataTime'

class Server
    def initialize(server, port, checkSize, checkTime)
        @serverSocket = TCPServer.new(server, port)
        @memory = Hash.new #collection used to save the key-value pair
        @expirations = Hash.new #collection used to save the time expiration info
        @memMutex = Mutex.new #mutex used to lock @memory methods
        @expMutex = Mutex.new #mutex used to lock @expirations methods
        @checkSize = checkSize
        @checkTime = checkTime
    end

=begin
It opens two threads to run the server and the purgeKeys methods to run concurrently.  
=end
   
    def startServer
        t1 = Thread.new { 
                run()
        }
        t2 = Thread.new {
            purgeKeys()
        }
        t1.join
        t2.join
    end

=begin
Runs the server in the given port.
Accepts the connection to the clients and reads the messages. Valides the instruction, and if no exception is raised
it calls the memcached command that applies. If any exception it's raised during a command, it sends a message to
the client.
com[0] = instruction
com[1] = key
com[2] = flag
com[3] = expiration time
com[4] = size of value
com[5] = casUnique
=end
    def run
        loop do
            Thread.start(@serverSocket.accept) do |client|
                begin
                    msg = client.gets.chop
                    com = msg.to_s.split #creates array with \s as delimiter
                    validateInstruction(com)
                    instr = com[0]
                    noReply = (com.size == 6 && com[5] == "noreply") #redefines it if inst = cas
                    case instr
                    when "add"                        
                        value = client.recv(com[4].to_i) #reads the value from the client
                        add(client, com[1], com[2].to_i, com[3].to_i, com[4].to_i, value, noReply)
                    when "set"
                        value = client.recv(com[4].to_i) #reads the value from the client
                        set(client, com[1], com[2].to_i, com[3].to_i, com[4].to_i, value, noReply)
                    when "prepend"
                        value = client.recv(com[4].to_i) #reads the value from the client
                        prepend(client, com[1], com[2].to_i, com[3].to_i, com[4].to_i, value, noReply)
                    when "append"
                        value = client.recv(com[4].to_i) #reads the value from the client
                        append(client, com[1], com[2].to_i, com[3].to_i, com[4].to_i, value, noReply)
                    when "cas"
                        noReply = (com.size == 7 && com[6] == "noreply")
                        value = client.recv(com[4].to_i) #reads the value from the client
                        cas(client, com[1], com[2].to_i, com[3].to_i, com[4].to_i, com[5].to_i, value, noReply)
                    when "get"
                        get(client, msg)
                    when "gets"
                        gets(client, msg)
                    end
                rescue => exception
                    if(!noReply)
                        client.print(exception.message)
                    end
                end
            end
        end
    end

=begin
Method that iterates through @expirations and purge keys that have expired. 
Only iterates if the amount of saved info is bigger than @checkSize.
After an iteration, it sleeps for @checkTime seconds until checks the condition again
Must reuse code from hasExpired? to avoid deadlock
=end
    def purgeKeys()
        loop do
            if @expirations.size >= @checkSize
                @expMutex.synchronize{
                    @expirations.each{|key, value|
                        hasExpired = false
                        if (value == nil or value.expiration == 0) #check if it does not exists or does not expires
                            hasExpired = false
                        else
                            if (value.unix and Time.now > value.expiration) #check if it's unix and bigger than now
                                hasExpired = true
                            end   
                            
                            if (!value.unix and (Time.now > value.timeAdded + value.expiration)) #check if it has exceeded the expiration time in seconds
                                hasExpired = true
                            end
                        end
                        if hasExpired
                            @expirations.delete(key)
                            deleteData(key) #deletes it from @memory
                        end
                    }
                }
                sleep(@checkTime)
            end
        end
    end

=begin
Checks if the value assigned to the given key has expired.
If the expiration value == 0, the key never expires.
=end
    def hasExpired?(key)
        value = getExp(key)
        if value == nil or value.expiration == 0
            false
        else
            if value.unix
                Time.now > value.expiration
            else
                expTime =  value.timeAdded + value.expiration
                Time.now > expTime
            end
        end
    end

#return true if the given string is numeric    
    def is_num?(string)
        true if Integer(string) rescue false
    end

=begin
Validates if the given instruction has an accurate format.
Checks for instrunction length, if 'noreply' or no value appears and the type of values recieved.
If the instruction doesn't have an accurate format it raises a CLIENT ERROR exception.
If the instruction isn't recognized, it raises an ERROR exception
=end
    def validateInstruction(instr)
        case instr[0]
        when "set", "add", "append", "prepend"
                invalidSize = (instr.size != 5 and instr.size != 6) #size 6 if 'noreply' was instructed 
                invalidFormat = (instr[5] != nil and instr[5] != "noreply")
                invalidType = !(is_num?(instr[2]) and is_num?(instr[3]) and is_num?(instr[4])) 
            if (invalidSize or invalidFormat or invalidType)
                raise "CLIENT_ERROR<wrong format instruction>\r\n"  
            end
        when "cas"
            invalidSize = (instr.size != 6 and instr.size != 7) #size 7 if 'noreply' was instructed 
            invalidFormat = (instr[6] != nil and instr[6] != "noreply")
            invalidType = !(is_num?(instr[2]) and is_num?(instr[3]) and is_num?(instr[4]) and is_num?(instr[5]))      
            if (invalidSize or invalidFormat or invalidType)
                raise "CLIENT_ERROR<wrong format instruction>\r\n"  
            end
        when "get", "gets"
            if instr.size < 2
                raise "CLIENT_ERROR<wrong format instruction>\r\n"  
            end
        else
            raise "ERROR\r\n"
        end
    end

#-------------------------MEMCACHED COMMANDS-------------------------------#

=begin
Adds a new value to @memory only if there's not already a value for the given key. 
If there is, it raises a NOT_STORED exception. Otherwise, it sends a STORED message to the client.
=end
    def add(client, key, flag ,expiration, size, value, noReply)
        if hasExpired?(key)
            purgeExpired(key)                      
        else
            if(getData(key) != nil)
                raise "NOT_STORED\r\n"  
            end
        end
        setData(key, 'temp') #sets arbitrary value so getData(key) != nil 
        casUnique = rand(2**32..2**64-1)
        data = SavedData.new(value, flag, casUnique, size)
        setData(key, data) #unfreezes the data
        expData = DataTime.new(expiration)
        setExp(key, expData)
        if(!noReply)
        client.print("STORED\r\n")
        end
    end

#Adds a new value to @memory, then it sends a STORED message to the client.
    def set(client, key, flag ,expiration, size, value, noReply)
        while (getData(key)!= nil and isFrozen?(key))
            #waits until it's unfrozen
        end
        freezeData(key) #freezes the data so it can't be accessed
        casUnique = rand(2**32..2**64-1)
        data = SavedData.new(value, flag, casUnique, size)
        setData(key, data) #unfreezes the data
        expData = DataTime.new(expiration)
        setExp(key, expData)
        if(!noReply)
            client.print("STORED\r\n")
        end
    end

=begin
Appends the given value to the one that already exists with the given key. It doesn't modify expiration
or flags value. If the key doesn't exists, it raises a NOT_STORED exception.
Otherwise, it sends a STORED message to the client.
=end
    def append(client, key, flag ,expiration, size, value, noReply)
        while (getData(key)!= nil and isFrozen?(key))
            #waits until it's unfrozen
        end
        freezeData(key) #freezes the data so it can't be accessed
        storedData = getData(key)      
        if hasExpired?(key)
            purgeExpired(key)
            raise "NOT_STORED\r\n" 
        end                         
        if(storedData == nil)
            raise "NOT_STORED\r\n"  
        end
        casUnique = rand(2**32..2**64-1)
        newValue = storedData.value + value
        data = SavedData.new(newValue, storedData.flag, casUnique, storedData.size + size)
        setData(key, data)#unfreezes the data
        if(!noReply)
            client.print("STORED\r\n")
        end
    end

=begin
Prepends the given value to the one that already exists with the given key. It doesn't modify expiration
or flags value. If the key doesn't exists, it raises a NOT_STORED exception.
Otherwise, it sends a STORED message to the client.
=end
    def prepend(client, key, flag ,expiration, size, value, noReply)  
        while (getData(key)!= nil and isFrozen?(key))
            #waits until it's unfrozen
        end
        freezeData(key) #freezes the data so it can't be accessed
        storedData = getData(key) 
        if hasExpired?(key)
            purgeExpired(key)
            raise "NOT_STORED\r\n" 
        end                         
        if(storedData == nil)
            raise "NOT_STORED\r\n"  
        end
        casUnique = rand(2**32..2**64-1)
        newValue = value + storedData.value
        data = SavedData.new(newValue, storedData.flag, casUnique, storedData.size + size)
        setData(key, data) #unfreezes the data
        if(!noReply)
            client.print("STORED\r\n")
        end
    end

=begin
Sets the given value to the one that already exists with the given key only if the current casUnique value
and the given match. If they don't it raises a EXISTS exception.
If the key doesn't exists, it raises a NOT_FOUND exception.
Otherwise, it sends a STORED message to the client.
=end
    def cas(client, key, flag ,expiration, size, clientCasUnique, value, noReply)     
        while (getData(key)!= nil and isFrozen?(key))
            #waits until it's unfrozen
        end
        freezeData(key) #freezes the data so it can't be accessed
        storedData = getData(key)
        if hasExpired?(key)
            purgeExpired(key)
            raise "NOT_FOUND\r\n" 
        end                         
        if(storedData == nil)
            raise "NOT_FOUND\r\n"  
        end
        if(storedData.casUnique == clientCasUnique.to_i)
            casUnique = rand(2**32..2**64-1)
            data = SavedData.new(value, flag, casUnique, size)
            setData(key, data)#unfreezes the data
            expData = DataTime.new(expiration)
            setExp(key, expData)
            if(!noReply)
                client.print("STORED\r\n")
            end
        else
            raise "EXISTS\r\n"
        end
    end

=begin
Returns the value, flag and size of the values associated to the array of keys received.
If one key has expired or doesn't exists in the collection, it's ignored.
It sends an END message to the client when it finishes.
=end
    def get(client, msg)
        com = msg.split
        cont = 1
        while com[cont] != nil #iterates through all the given keys
            key = com[cont]
            savedData = getData(key)
            if savedData != nil
                if hasExpired?(key)
                    purgeExpired(key)                      
                else
                    response = "VALUE #{key} #{savedData.flag} #{savedData.size}\r\n"
                    client.print(response)
                    value = "#{savedData.value}\r\n"
                    client.print(value)                    
                end
            end
            cont = cont + 1        
        end
        client.print("END\r\n")
    end

=begin
Returns the value, flag, size, casUnique of the values associated to the array of keys received.
If one key has expired or doesn't exists in the collection, it's ignored.
It sends an END message to the client when it finishes.
=end
    def gets(client, msg)
        com = msg.split
        cont = 1
        while com[cont] != nil #iterates through all the given keys
            key = com[cont]
            savedData = getData(key)
            if savedData != nil
                if hasExpired?(key)
                    purgeExpired(key)                        
                else
                    response = "VALUE #{key} #{savedData.flag} #{savedData.size} #{savedData.casUnique}\r\n"
                    client.print(response)
                    value = "#{savedData.value}\r\n"
                    client.print(value)                    
                end
            end
            cont = cont + 1        
        end
        client.print("END\r\n")
    end

    def killServer()
        @serverSocket.close
    end

#-------------------------COLLECTIONS METHODS-------------------------------#

    #deletes the data asociated to the given key from both @memory and @expirations
    def purgeExpired(key)
        deleteData(key)
        deleteExp(key)
    end

    #returns the data asociated to the given key from @memory 
    def getData(key)
        @memMutex.synchronize{
        @memory[key]
        }
    end

    #deletes the data asociated to the given key from @memory
    def deleteData(key)
        @memMutex.synchronize{
        @memory.delete(key)
        }
    end

    #sets the value asociated to the given key in @memory
    def setData(key, value)
        @memMutex.synchronize{
            @memory[key] = value
        }
    end

    #returns true if the given key is frozen in @memory
    def isFrozen?(key)
        @memMutex.synchronize{
            @memory[key].frozen?
        }
    end

    #sets the value asociated to the given key in @memory
    def freezeData(key)
        @memMutex.synchronize{
            @memory[key].freeze
        }
    end

    #returns the expiration data asociated to the given key from @expirations 
    def getExp(key)
        @expMutex.synchronize{
        @expirations[key]
        }
    end

    #deletes the expiration data asociated to the given key from @expirations
    def deleteExp(key)
        @expMutex.synchronize{
        @expirations.delete(key)
        }
    end

    #sets the expiration value asociated to the given key in @expirations
    def setExp(key, value)
        @expMutex.synchronize{
            @expirations[key] = value
        }
    end

end