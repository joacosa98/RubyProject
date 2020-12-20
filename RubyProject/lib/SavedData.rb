class SavedData
    # constructor method
   def initialize(value, flag, casUnique, size)
        @value = value
        @flag = flag   
        @casUnique = casUnique
        @size = size
   end


    attr_accessor :value, :casUnique, :flag, :size, :unix
end
