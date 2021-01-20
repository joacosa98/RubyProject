class ServerMemory
    def initialize
        @collection = Hash.new
    end
    
    attr_reader :collection

    #returns the data asociated to the given key from @memory 
    def get_data(key)
        @collection[key]
    end

    #deletes the data asociated to the given key from @memory
    def delete_data(key)
        @collection.delete(key)
    end

    #sets the value asociated to the given key in @memory
    def set_data(key, value)
        @collection[key] = value
    end
       
end