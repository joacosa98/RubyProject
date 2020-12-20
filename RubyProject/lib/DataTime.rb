class DataTime
    # constructor method
   def initialize(expiration)
        if expiration > 2592000 # if the value is higher than one day in seconds, it is considered Unix time
            @unix = true
            @expiration = Time.at(expiration)
        else
            @unix = false
            @expiration = expiration
        end 
        @timeAdded = Time.now
   end


    attr_accessor :timeAdded, :expiration, :unix
end