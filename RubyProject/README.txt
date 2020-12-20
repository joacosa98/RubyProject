------------------------SERVER AND CLIENT------------------------
The server, port, checkSize and checkTime can be set in the Config.yml file inside the RubyProject folder.
-checkSize is the minimum size of data stored for which the server starts to check for expired keys
-checkTime is the amount of time in seconds until the condition of checkSize <= data stored is evaluated again
First, the MainServer.rb must be executed and then the MainClient.rb.
The program will ask for a server address and a port to connect to.

Once connected, the client can start to send instructions to the server.
The commands allowed are: add, set, append, prepend, cas, get and gets.
If the command given is not one of these, the server will throw an exception.
The format for the commands are the following:

-<command name> <key> <flags> <exptime> <bytes> [noreply]
-cas <key> <flags> <exptime> <bytes> <cas unique> [noreply]
    --command name is one of: add, set, append, prepend
    --flags, exptime, bytes and cas unique must be integers
Afterwards, the server expects a value. The client won't send the value until the number of <bytes> has been read.    

-get <keys>
-gets <keys>
    --<keys> can be a group of values separated by a white space

If the instructions don't respect the format described, the server will throw an exception. 

The client can exit the server by sending 'exit'.

------------------------UNIT TESTS------------------------
The server, port, checkSize and checkTime can be set in the Config.yml file inside the RubyProject folder.
Open a cmd in the Ruby Project's folder and execute the command below.  
rspec spec spec/add_spec.rb
After executing all tests, the expected result is: 48 examples, 0 failures.
The server must be down before running the unit tests.    


------------------------LOAD TESTS------------------------
The server and  port can be set in the Config.csv file inside the jmeter folder.
Open a cmd in JMeter’s bin folder and execute the command below.  
jmeter -n -t [RubyProject folder location]\jmeter\[.jmx file] -l testresults.jtl.
Then you can open the testresults.jml from the GUI of JMeter to see the results.
The server must be on before running the load tests, and restarted after running each one.
