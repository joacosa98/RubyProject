require 'socket'
require_relative 'saved_data'
require_relative 'data_time'
require_relative 'attend_client'
require_relative 'server_memory'

class Server
    def initialize(server, port, checkTime)
        @server_socket = TCPServer.new(server, port)
        @memory = ServerMemory.new #collection used to save the key-value pair
        @expirations = ServerMemory.new #collection used to save the time expiration info
        @mem_mutex = Mutex.new #mutex used to lock @memory methods
        @exp_mutex = Mutex.new #mutex used to lock @expirations methods
        @emptyMutex = Mutex.new #mutex used to lock adding new elements
        @check_time = checkTime
    end


    #It opens two threads to run the server and the purgeKeys methods to run concurrently.     
    def start_server
        run()
        t2 = Thread.new {
            purge_keys()
        }
        #t2.join
    end


    #Runs the server in the given port.
    #Accepts the connection to the clients and reads the messages. Valides the instruction, and if no exception is raised
    #it calls the memcached command that applies. If any exception it's raised during a command, it sends a message to
    #the client.
    #instr[0] = command
    #instr[1] = key
    #instr[2] = flag
    #instr[3] = expiration time
    #instr[4] = size of value
    #instr[5] = cas_unique 
    def run
        loop do
            Thread.start(@server_socket.accept) do |client|
                begin
                    attend = AttendClient.new(client)
                    instr = attend.read_command()
                    command = instr[0]
                    no_reply = (instr.size == 6 && instr[5] == "noreply") #redefines it if inst == cas
        
                    case command
                        when "add"
                            value = attend.read_value(instr[4].to_i) #reads the value from the client                       
                            add(client, instr[1], instr[2].to_i, instr[3].to_i, instr[4].to_i, value, no_reply)
                        when "set"
                            value = attend.read_value(instr[4].to_i) #reads the value from the client
                            set(client, instr[1], instr[2].to_i, instr[3].to_i, instr[4].to_i, value, no_reply)
                        when "prepend"
                            value = attend.read_value(instr[4].to_i) #reads the value from the client
                            prepend(client, instr[1], instr[2].to_i, instr[3].to_i, instr[4].to_i, value, no_reply)
                        when "append"
                            value = attend.read_value(instr[4].to_i) #reads the value from the client
                            append(client, instr[1], instr[2].to_i, instr[3].to_i, instr[4].to_i, value, no_reply)
                        when "cas"
                            no_reply = (instr.size == 7 && instr[6] == "noreply")
                            value = attend.read_value(instr[4].to_i) #reads the value from the client
                            cas(client, instr[1], instr[2].to_i, instr[3].to_i, instr[4].to_i, instr[5].to_i, value, no_reply)
                        when "get"
                            get(client, instr)
                        when "gets"
                            gets(client, instr)
                    end
                rescue => exception
                    if(!no_reply)
                        client.print(exception.message)
                    end
                end
            end
        end
    end

    #Method that iterates through @expirations and purge keys that have expired. 
    #Only iterates if the amount of saved info is bigger than @checkSize.
    #After an iteration, it sleeps for @check_time seconds until checks the condition again
    #Must reuse code from has_expired? to avoid deadlock   
    def purge_keys()
        loop do
                @exp_mutex.synchronize{
                    @expirations.collection.each{|key, value|
                        has_expired = false
                        if value.expiration != 0 # if value.expiration == 0 never expires
                            
                            #checks if it's unix and bigger than now
                            if (value.unix and Time.now > value.expiration) 
                                has_expired = true
                            end   
                            
                            #checks if it has exceeded the expiration time in seconds
                            if (!value.unix and (Time.now > value.time_added + value.expiration)) 
                                has_expired = true
                            end
                        end

                        if has_expired
                            @expirations.delete_data(key)
                            delete_data(key) #deletes it from @memory
                        end
                    }
                }
            sleep(@check_time)
        end
    end

    #Checks if the value assigned to the given key has expired.
    #If the expiration value == 0, the key never expires.
    def has_expired?(key)
        value = get_exp(key)

        if value == nil or value.expiration == 0
            false
        else
            if value.unix
                Time.now > value.expiration
            else
                exp_time =  value.time_added + value.expiration
                Time.now > exp_time
            end
        end
    end


#-------------------------MEMCACHED COMMANDS-------------------------------#

    #Adds a new value to @memory only if there's not already a value for the given key. 
    #If there is, it raises a NOT_STORED exception. Otherwise, it sends a STORED message to the client.
    def add(client, key, flag ,expiration, size, value, no_reply)
        @emptyMutex.synchronize{
            if(get_data(key) != nil && !has_expired?(key))
                raise "NOT_STORED\r\n"  
            end
            
            cas_unique = rand(2**32..2**64-1)
            data = SavedData.new(value, flag, cas_unique, size)
            set_data(key, data) 
            exp_data = DataTime.new(expiration)
            set_exp(key, exp_data)
            
            if(!no_reply)
                client.print("STORED\r\n")
            end
        } 
    end

    #Adds a new value to @memory, then it sends a STORED message to the client.
    def set(client, key, flag ,expiration, size, value, no_reply)
        mutex = nil
        if(get_data(key) != nil && !has_expired?(key))
            semaphore = get_data(key).semaphore #sets the mutex of the element
        else
            semaphore = @emptyMutex #sets the mutex to add a new element
        end
        
        semaphore.synchronize{
            cas_unique = rand(2**32..2**64-1)
            data = SavedData.new(value, flag, cas_unique, size)
            set_data(key, data) 
            exp_data = DataTime.new(expiration)
            set_exp(key, exp_data)
            
            if(!no_reply)
                client.print("STORED\r\n")
            end
        }
    end

    #Appends the given value to the one that already exists with the given key. It doesn't modify expiration
    #or flags value. If the key doesn't exists, it raises a NOT_STORED exception.
    #Otherwise, it sends a STORED message to the client.
    def append(client, key, flag ,expiration, size, value, no_reply)
        
        storedData = get_data(key)      
        
        if has_expired?(key)
            purge_expired(key)
            raise "NOT_STORED\r\n" 
        end                         
        
        if(storedData == nil)
            raise "NOT_STORED\r\n"  
        end

        storedData.semaphore.synchronize{
            cas_unique = rand(2**32..2**64-1)
            new_value = "#{storedData.value}#{value}"
            data = SavedData.new(new_value, storedData.flag, cas_unique, storedData.size + size)
            set_data(key, data)

            if(!no_reply)
                client.print("STORED\r\n")
            end
        }
    end

    #Prepends the given value to the one that already exists with the given key. It doesn't modify expiration
    #or flags value. If the key doesn't exists, it raises a NOT_STORED exception.
    #Otherwise, it sends a STORED message to the client.
    def prepend(client, key, flag ,expiration, size, value, no_reply)  
        
        storedData = get_data(key) 
        
        if has_expired?(key)
            purge_expired(key)
            raise "NOT_STORED\r\n" 
        end                         
        
        if(storedData == nil)
            raise "NOT_STORED\r\n"  
        end

        storedData.semaphore.synchronize{
            cas_unique = rand(2**32..2**64-1)
            new_value = "#{value}#{storedData.value}"
            data = SavedData.new(new_value, storedData.flag, cas_unique, storedData.size + size)
            set_data(key, data) 
            
            if(!no_reply)
                client.print("STORED\r\n")
            end
        }
    end

    #Sets the given value to the one that already exists with the given key only if the current cas_unique value
    #and the given match. If they don't it raises a EXISTS exception.
    #If the key doesn't exists, it raises a NOT_FOUND exception.
    #Otherwise, it sends a STORED message to the client.
    def cas(client, key, flag ,expiration, size, client_cas_unique, value, no_reply)     
        
        storedData = get_data(key)
        
        if has_expired?(key)
            purge_expired(key)
            raise "NOT_FOUND\r\n" 
        end                         
        
        if(storedData == nil)
            raise "NOT_FOUND\r\n"  
        end
        
        storedData.semaphore.synchronize{
            if(storedData.cas_unique == client_cas_unique.to_i)
                cas_unique = rand(2**32..2**64-1)
                data = SavedData.new(value, flag, cas_unique, size)
                set_data(key, data)
                exp_data = DataTime.new(expiration)
                set_exp(key, exp_data)
                
                if(!no_reply)
                    client.print("STORED\r\n")
                end
            else
                raise "EXISTS\r\n"
            end
        }
    end

    #Returns the value, flag and size of the values associated to the array of keys received.
    #If one key has expired or doesn't exists in the collection, it's ignored.
    #It sends an END message to the client when it finishes.
    def get(client, instr)
        cont = 1
        
        while instr[cont] != nil #iterates through all the given keys
            key = instr[cont]
            saved_data = get_data(key)
            
            if saved_data != nil
                if has_expired?(key)
                    purge_expired(key)                      
                else
                    response = "VALUE #{key} #{saved_data.flag} #{saved_data.size}\r\n"
                    client.print(response)
                    value = "#{saved_data.value}\r\n"
                    client.print(value)                    
                end
            end
            cont = cont + 1        
        end
        
        client.print("END\r\n")
    end

    #Returns the value, flag, size, cas_unique of the values associated to the array of keys received.
    #If one key has expired or doesn't exists in the collection, it's ignored.
    #It sends an END message to the client when it finishes.
    def gets(client, instr)
        cont = 1
        
        while instr[cont] != nil #iterates through all the given keys
            key = instr[cont]
            saved_data = get_data(key)
            
            if saved_data != nil
                if has_expired?(key)
                    purge_expired(key)                        
                else
                    response = "VALUE #{key} #{saved_data.flag} #{saved_data.size} #{saved_data.cas_unique}\r\n"
                    client.print(response)
                    value = "#{saved_data.value}\r\n"
                    client.print(value)                    
                end
            end
            cont = cont + 1        
        end
        
        client.print("END\r\n")
    end

    def kill_server()
        @server_socket.close
    end

#-------------------------COLLECTIONS METHODS-------------------------------#

    #deletes the data asociated to the given key from both @memory and @expirations
    def purge_expired(key)
        delete_data(key)
        delete_exp(key)
    end

    #returns the data asociated to the given key from @memory 
    def get_data(key)
        @memory.get_data(key)
        
    end

    #deletes the data asociated to the given key from @memory
    def delete_data(key)
        @mem_mutex.synchronize{
        @memory.delete_data(key)
        }
    end

    #sets the value asociated to the given key in @memory
    def set_data(key, value)
        @mem_mutex.synchronize{
            @memory.set_data(key, value)
        }
    end

    #returns the expiration data asociated to the given key from @expirations 
    def get_exp(key)
        @expirations.get_data(key)
    end

    #deletes the expiration data asociated to the given key from @expirations
    def delete_exp(key)
        @exp_mutex.synchronize{
        @expirations.delete_data(key)
        }
    end

    #sets the expiration value asociated to the given key in @expirations
    def set_exp(key, value)
        @exp_mutex.synchronize{
            @expirations.set_data(key, value)
        }
    end

end
