
module Okey
  class Table
    attr_reader :chairs, :state
    def initialize
      @chairs = {}
      @game = nil
      @state = :waiting
    end
    
    def initialize_game
      @game = Game.new(self)
      @state = :started
    end
    
    # returns the added position or nil
    def add_user(user)
      index = 0
      position = nil
      while index < 4
        key = Chair::POSITIONS[index]
        if !@chairs.has_key?(key)
          position = key
          @chairs.merge!({ key => user})
          break
        end
        index += 1
      end
      user.position = position
      position        
    end
    
    def get_user(position)
      @chairs[position]
    end
    
    def remove(position)
      @chairs.delete(position)
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
    
    def game_started?
      @state == :started
    end
    
    def turn
      @game.turn if game_started?
    end
    
    def throw_tile(user, tile)
      @game.throw_tile(user, tile)
    end
    
    def throw_to_finish(user, hand, tile)
      success = @game.throw_to_finish(user, hand, tile)
      if success
        @state = :finished
      end
      success
    end
    
    def draw_tile(user, center)
      @game.draw_tile(user, center)
    end
    
    def middle_tile_count
      @game.middle_tile_count
    end
    
    
  end
end