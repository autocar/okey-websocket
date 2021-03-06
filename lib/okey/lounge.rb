require 'set'

module Okey
  class Lounge
    NUM_OF_ROOMS = 24
    
    def initialize(user_controller)
      @user_controller = user_controller
      @empty_rooms = {}
      @players = Set.new
    end

    def join_lounge(user)
      user.onmessage{ |msg|
        error = handle_request(user, msg)
        if error
          user.send error
        end
      }
      user.onclose {
        @players.delete(user)
      }
      # subscribe
      user.send({ :status => :join_lounge, :points => user.points })
      @players << user
    end

    def leave_lounge(user)
      @players.delete(user)
    end
     

    def destroy_room(room)
      r = @empty_rooms.delete(room.name)
    end


    def join_room(room_name, user)
      room = @empty_rooms[room_name]
      
      if room.nil?
        return LoungeMessage.getJSON(:error, nil, 'Cannot find the room')
      elsif !room.has_bot?
         return LoungeMessage.getJSON(:error, nil, 'Room is full')
      end
      room.join_room(user)
      nil
    end
    
    private

    def handle_request(user, msg)
      json = nil
      begin
        json = JSON.parse(msg)
      rescue JSON::ParserError
        json = nil
      end
      
      return LoungeMessage.getJSON(:error, nil, 'Messaging error') if json.nil?
      error = nil
      case json['action']
      when 'join_room'
        room_name = json['room_name']
        return LoungeMessage.getJSON(:error, nil, 'Room name cannot be empty') if room_name.nil? || room_name.empty?
        error = join_room(json['room_name'], user)
      when 'refresh_list'
        send_room_json(user)
      when 'create_room'
        room_name = json['room_name']
        unless room_name.nil?
          room_name = room_name.slice(/\S+(\s*\S+)*/); # Get rid of the spaces
        end
        return LoungeMessage.getJSON(:error, nil, 'Room name cannot be blank') if room_name.nil? || room_name.empty?
        error = create_and_join_room(room_name, user)
      when 'leave_lounge'
        leave_lounge(user)
        @user_controller.subscribe(user)
      else # Send err
        return LoungeMessage.getJSON(:error, nil, 'Messaging error')
      end
      error
    end

    def create_and_join_room(room_name, user)
      return LoungeMessage.getJSON(:error, nil, 'Room name is already taken') if @empty_rooms.has_key?(room_name)
      
      room = Room.new(self, room_name)
      room.join_room(user)
      @empty_rooms.merge!({ room_name => room })
      
      nil
    end

    def send_room_json(user)
      room_list = []
      keys = @empty_rooms.keys.shuffle
      keys.each do |key|
        room = @empty_rooms[key]
        name_position = []
        room.chairs.each { |pos, usr|
          name_position << { :name => usr.username, :position => pos, :points => usr.points } unless usr.bot?
        }
        room_list << { :room_name => room.name, :count => room.count, :users => name_position }
        break if room_list.length >= NUM_OF_ROOMS
      end
      json = { :status => :lounge_update, :player_count => @players.length, :list => room_list }
      user.send(json)
    end

  end
end