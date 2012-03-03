
module Okey
  class Table
    attr_reader :chairs
    def initialize
      @chairs = {}
    end
    
    # returns the added position or nil
    def add_user(user)
      index = 0
      position = nil
      while index < 4
        key = Chair::CARDINALS[index]
        if !@chairs.has_key?(key)
          position = key
          @chairs.merge!({ key => user})
          break
        end
        index += 1
      end 
      position        
    end
    
    def remove(cardinal)
      @chairs.delete(cardinal)
    end
    
    def count
      @chairs.length
    end
    
    def full?
      @chairs.length >= 4
    end
    
    def empty?
      @chairs.length <= 0
    end
    
  end
end