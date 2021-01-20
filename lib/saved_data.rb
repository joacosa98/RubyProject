class SavedData
    # constructor method
   def initialize(value, flag, cas_unique, size)
        @value = value
        @flag = flag   
        @cas_unique = cas_unique
        @size = size
        @semaphore = Mutex.new #mutex used to lock the element
   end


    attr_accessor :value, :cas_unique, :flag, :size, :unix, :semaphore
end
