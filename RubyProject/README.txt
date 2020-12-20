------------------------SERVER AND CLIENT------------------------
In the Config.yml file inside the RubyProject folder the server, port, checkSize and checkTime can be setted.
First, the MainServer.rb must be executed and then the MainClient.rb.
The program will ask for a server address and a port to connect to.

After being connected, the client can start sending instructions to the server.
The commands permitted are: add, set, append, prepend, cas, get and gets.
If the command given is not one of this, the server will throw an exception.
The format for the commands is the following:

-<command name> <key> <flags> <exptime> <bytes> [noreply]
-cas <key> <flags> <exptime> <bytes> <cas unique> [noreply]
    --command name is one of: add, set, append, prepend, cas
    --flags, exptime, bytes and cas unique must be integers
After, the server expects a value. the client won't send the value until the number of <bytes> has been read.    

-get <keys>
-gets <keys>
    --<keys> can be a group of values separated by a white space

If the instructions doesn't respect the format described, the server will throw an exception. 

The client can exit the server by sending 'exit'.

------------------------UNIT TESTS------------------------
In the Config.yml file inside the spec folder the server, port, checkSize and checkTime can be setted.
Open a cmd in the Ruby Project's folder and execute the command below.  
rspec spec spec/add_spec.rb
After executing all tests the expected result is: 48 examples, 0 failures.
The server must be down before running the unit tests.    


------------------------LOAD TESTS------------------------
In the Config.csv file inside the jmeter folder the server and  port can be setted.
Open a cmd in JMeter’s bin folder and execute the command below.  
jmeter -n -t [RubyProject folder location]\jmeter\[.jmx load test file] -l testresults.jtl.
Then you can open the testresults.jml from the GUI of JMeter to see the results.
The server must be on before running the load tests, and restarted after running each one.