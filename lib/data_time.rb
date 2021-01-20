class DataTime

   def initialize(expiration)
        if expiration > 2592000 # if the value is higher than one day in seconds, it is considered Unix time
            @unix = true
            @expiration = Time.at(expiration)
        else
            @unix = false
            @expiration = expiration
        end 
        @time_added = Time.now
   end


    attr_accessor :time_added, :expiration, :unix
end