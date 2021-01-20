
## ---SERVER AND CLIENT--- 
------------
In the Config.yml file inside the RubyProject folder the server, port, checkSize and checkTime can be setted.  
First, the MainServer.rb must be executed and then the MainClient.rb.  
The program will ask for a server address and a port to connect to.  
  
After being connected, the client can start sending instructions to the server.
The commands permitted are: add, set, append, prepend, cas, get and gets.  
If the command given is not one of this, the server will throw an exception.
If the instructions doesn't respect the format described, the server will throw an exception.

The client can exit the server by sending 'exit'.
  
###  Storage commands  
 `<command name> <key> <flags> <exptime> <bytes> [noreply]`
 
 `cas <key> <flags> <exptime> <bytes> <cas unique> [noreply]`

* &lt;command name&gt; must be one of: add, set, append, prepend, cas  
* &lt;flags&gt;, &lt;exptime&gt;, &lt;bytes&gt; and &lt;cas unique&gt; must be integers  

After, the server expects a value. the client won't send the value until the number of <bytes> has been read.

#### Response from the server
* &lt;ERROR&gt; the command given does not exists
* &lt;CLIENT_ERROR&gt; the given format of the command has mistakes
* &lt;STORED&gt; the given key was correctly stored
* &lt;NOT_STORED&gt; the given key was not stored
* &lt;EXISTS&gt; the item you are trying to store with
a "cas" command has been modified since your last fetch
* &lt;NOT_FOUND&gt; the item you are trying to store
with a "cas" command did not exist


### Retrieval commands
`get <keys>`

`gets <keys>`

* &lt;keys&gt; can be a group of values separated by a white space

#### Response from the server
* &lt;ERROR&gt; the command given does not exists
* &lt;CLIENT_ERROR&gt; the given format of the command has mistakes
* VALUE &lt;key&gt; &lt;flag&gt; &lt;bytes&gt; [&lt;cas_unique&gt;]

&lt;data block&gt;
    * &lt;key&gt; is the key for the item being sent
    * &lt;flag&gt; is the flags value set by the storage command
    * &lt;bytes&gt; is the length of the data block to follow
    * &lt;cas_unique&gt; is a unique integer that uniquely identifies
    this specific item
    * &lt;data block&gt; is the data for this item

## ---UNIT TESTS--- 
------------
In the Config.yml file inside the spec folder the server, port, checkSize and checkTime can be setted.  
Open a cmd in the Ruby Project's folder and execute the command below.

`rspec spec spec/add_spec.rb `

After executing all tests the expected result is: 48 examples, 0 failures.  
The server must be down before running the unit tests.


## ---LOAD TESTS--- 
------------ 
In the Config.csv file inside the jmeter folder the server and  port can be setted.  
Open a cmd in JMeter’s bin folder and execute the command below.  

`jmeter -n -t [RubyProject folder location]\jmeter\[.jmx load test file] -l testresults.jtl `

Then you can open the testresults.jml from the GUI of JMeter to see the results.  
The server must be on before running the load tests, and restarted after running each one.  
