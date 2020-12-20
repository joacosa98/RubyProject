require 'socket'
class Client

    def initialize(server, port)
        @server = server
        @port = port
        @socket = nil
    end
    attr_accessor :socket

    #Reads up to size characters
    def readMsg(size)
        value = ""
        sizeAux = size
        while sizeAux > 0 do
            msg = $stdin.gets.chop
            valueAux = msg[0..sizeAux-1]
            valueAux = valueAux + "\n"
            value = value + valueAux
            sizeAux = sizeAux - valueAux.length
        end
        value
    end

    #Tries to connect to the given port and runs the connection with the server. 
    #If it failes, it gives the client an error message and closes
    def connect
        begin
            TCPSocket.new(@server, @port) #used for checking the connection
            puts "Connection successful!"
            run()
        rescue => exception
            puts "Failed to connect to : #{@server}:#{@port}"
            puts "Closing..."
            sleep(2)
        end
        
    end

    #Read a response line from the socket
    def next_line_readable?
        readfds, writefds, exceptfds = select([@socket], nil, nil, 0.1)
        readfds #Will be nil if next line can't be red
    end

    #Runs the connection to the server in the given port
    #First it reads the instruction, and sends it to the socket
    #If the instruction must send a value, it reads up to *size* characters and sends the value to the socket
    #Then, it prints the line that the socket send as response
    def run
        while true do
            begin
                msg = $stdin.gets
                if msg.to_s.include? "exit"
                    break
                else
                    setSocket() #must do it in every run
                    sendData(msg)
                    com = msg.to_s.split
                    if (com[0] == "add" or com[0] == "set" or com[0] == "cas" or com[0] == "append" or com[0] == "prepend") #must send value
                        value = readMsg(com[4].to_i) #com[4] -> size of the value to read
                        sendData(value)
                    end
                    retrieveData()#prints data
                    #while next_line_readable?(@socket)
                     #   puts @socket.gets.chop #puts every line that the socket sends as response
                    #end
                end
            rescue => exception
                puts exception.message
                puts "A server failure has been encountered"
                puts "Closing..."
                sleep(2)
                break
            end
        end
    end

    #sets a connection to the port
    def setSocket
        @socket = TCPSocket.new(@server, @port) 
    end
    
    #send the given value to the server
    def sendData(value)
        msg = value.chop + "\r\n"
        @socket.print(msg)
    end

    #retrieves data from the server and prints it to the client
    def retrieveData
        response = ''
        while next_line_readable?
            response = @socket.gets.chop
            puts response
        end
        response #returns last valid line
    end
end

