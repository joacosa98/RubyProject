class AttendClient
    def initialize(client)
        @client = client
    end

    #reads one line from the client and validates the format
    def read_command()
        msg = @client.gets.chop
        instr = msg.to_s.split #creates array with \s as delimiter
        validate_instruction(instr)
        instr
    end

    #reads up to size characters from the client
    def read_value(size)
        @client.recv(size) 
    end

    #Validates if the given instruction has an accurate format.
    #Checks for instrunction length, if 'noreply' or no value appears and the type of values recieved.
    #If the instruction doesn't have an accurate format it raises a CLIENT ERROR exception.
    #If the instruction isn't recognized, it raises an ERROR exception
    def validate_instruction(instr)
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

    
    #returns true if the given string is numeric    
    def is_num?(string)
        true if Integer(string) rescue false
    end

end