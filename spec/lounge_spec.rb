require 'spec_helper'

describe Okey::Lounge do
  include EventMachine::SpecHelper

  describe "initialization" do

    it "should have default values" do
      em {
        lounge = Okey::Lounge.new(Okey::UserController.new('0.0.0'))
        lounge.instance_variable_get(:@online_player_count).should == 0
        lounge.instance_variable_get(:@empty_rooms).should == {}
        lounge.instance_variable_get(:@full_rooms).should == {}

        done
      }
    end

  end

  describe "join lounge" do

    before(:each) do
      @user = Okey::User.new(FakeWebSocketClient.new({}))
    end

    it "should send success json" do
      em {
        Okey::Lounge.new(Okey::UserController.new('0.0.0')).join_lounge(@user)
        # @user.websocket.get_onmessage.call("")

        json = @user.websocket.sent_data
        parsed = JSON.parse(json)
        parsed["status"].should == "success"
        parsed["payload"]["message"].should == "authentication success"

        done
      }
    end

    it "should increase the player count by one" do
      em {
        @lounge = Okey::Lounge.new(Okey::UserController.new('0.0.0'))
        count = @lounge.instance_variable_get(:@online_player_count)
        @lounge.join_lounge(@user)
        @lounge.instance_variable_get(:@online_player_count).should == count + 1
        done
      }
    end

    it "should change websocket procs" do
      em {
        @lounge = Okey::Lounge.new(Okey::UserController.new('0.0.0'))
        onmessage = @user.websocket.get_onmessage
        onclose = @user.websocket.get_onclose
        onerror = @user.websocket.get_onerror
        @lounge.join_lounge(@user)
        @user.websocket.get_onmessage.should_not == onmessage
        # @user.websocket.get_onclose.should_not == onclose TODO
        # @user.websocket.get_onerror.should_not == onerror TODO

        done
      }
    end

  end

  describe "messaging" do

    before(:each) do
      @user = Okey::User.new(FakeWebSocketClient.new({}))
      @refresh_request_attr = { :action => 'refresh_list' }
      @create_json_attr = { :action => 'create_room', :room_name => 'new room'}
      @join_json_attr = { :action => 'join_room', :room_name => 'room1'}
      @lounge = Okey::Lounge.new(Okey::UserController.new('0.0.0'))
      @lounge.join_lounge(@user)
      @user.websocket.sent_data = nil
    end

    describe "undefined request" do

      it "should send error json on empty string" do
        em {
          @user.websocket.get_onmessage.call("")
          json = @user.websocket.sent_data
          parsed = JSON.parse(json)

          parsed["status"].should == "error"
          parsed["payload"]["message"].should == "messaging error"

          done
        }
      end

      it "should send error json on empty json" do
        em {
          @user.websocket.get_onmessage.call({}.to_json)
          json = @user.websocket.sent_data
          parsed = JSON.parse(json)

          parsed["status"].should == "error"
          parsed["payload"]["message"].should == "messaging error"

          done
        }
      end

      it "should send error json on undefined request" do
        em {
          @user.websocket.get_onmessage.call({ :dummy_request => :val }.to_json)
          json = @user.websocket.sent_data
          parsed = JSON.parse(json)

          parsed["status"].should == "error"
          parsed["payload"]["message"].should == "messaging error"

          done
        }
      end

    end

    describe "update request" do

      it "should send appropriate json" do
        em {
          @user.websocket.get_onmessage.call(@refresh_request_attr.to_json)
          json = @user.websocket.sent_data
          parsed = JSON.parse(json)

          parsed["status"].should == "lounge_update"
          parsed["payload"]["list"].should be_instance_of(Array)
          parsed["payload"]["player_count"].to_i.should == @lounge.instance_variable_get(:@online_player_count)
          done
        }
      end

    end

    describe "join room request" do

      describe "success" do

        it "should join the user in" do
          em {
            user1 = Okey::User.new(FakeWebSocketClient.new({}))
            @lounge.join_lounge(user1)
            user1.websocket.get_onmessage.call((@create_json_attr).to_json) # create room

            rooms = @lounge.instance_variable_get(:@empty_rooms)
            room = rooms[@create_json_attr[:room_name]]
            room.should_receive(:join_room).with(@user)

            @join_json_attr.merge!({ :room_name => @create_json_attr[:room_name] })
            @user.websocket.get_onmessage.call((@join_json_attr).to_json) # join request

            done
          }
        end

      end

      describe "failure" do
        
        it "should return error json if the room is full" do
          em {
            user1 = Okey::User.new(FakeWebSocketClient.new({}))
            user2 = Okey::User.new(FakeWebSocketClient.new({}))
            user3 = Okey::User.new(FakeWebSocketClient.new({}))
            user4 = Okey::User.new(FakeWebSocketClient.new({}))
            
            @lounge.join_lounge(user1)
            @lounge.join_lounge(user2)
            @lounge.join_lounge(user3)
            @lounge.join_lounge(user4)
            user1.websocket.get_onmessage.call((@create_json_attr).to_json) # create room
            
            @join_json_attr.merge!({ :room_name => @create_json_attr[:room_name] })
            user2.websocket.get_onmessage.call((@join_json_attr).to_json) # join room
            user3.websocket.get_onmessage.call((@join_json_attr).to_json) # join room
            user4.websocket.get_onmessage.call((@join_json_attr).to_json) # join room
            
            @user.websocket.get_onmessage.call((@join_json_attr).to_json) # join room
            json = @user.websocket.sent_data
            parsed = JSON.parse(json)
            
            parsed["status"].should == "error"
            parsed["payload"]["message"].should == "room is full"
            done
          }
        end

        it "should return error json if the room cannot be found" do
          em {
            @user.websocket.get_onmessage.call((@join_json_attr).to_json) # join room
            json = @user.websocket.sent_data
            parsed = JSON.parse(json)
            
            parsed["status"].should == "error"
            parsed["payload"]["message"].should == "cannot find the room"
            done
          }
        end
        
      end

      it "should send an error json if the room field is nil or empty" do
        em {
          @user.websocket.get_onmessage.call((@join_json_attr.merge!({ :room_name => "" })).to_json)
          json = @user.websocket.sent_data
          parsed = JSON.parse(json)

          parsed["status"].should == "error"
          parsed["payload"]["message"].should == "room name cannot be empty"

          @user.websocket.sent_data = nil
          @join_json_attr.delete(:room_name)
          @user.websocket.get_onmessage.call(@join_json_attr.to_json)
          json = @user.websocket.sent_data
          parsed = JSON.parse(json)

          parsed["status"].should == "error"
          parsed["payload"]["message"].should == "room name cannot be empty"
          done
        }
      end

    end

    describe "create room request" do

      describe "success" do
        it "should create a new room with attributes" do
          em {
            Okey::Room.should_receive(:new).with(@lounge, @create_json_attr[:room_name], @user)
            @user.websocket.get_onmessage.call((@create_json_attr).to_json)
            done
          }
        end

        it "should merge the room to the empty room hash" do
          em {
            empty_rooms_length = @lounge.instance_variable_get(:@empty_rooms).length
            @user.websocket.get_onmessage.call((@create_json_attr).to_json)
            @lounge.instance_variable_get(:@empty_rooms).length.should == empty_rooms_length + 1
            done
          }
        end

      end

      describe "failure" do

        it "should send error json if the room name is already in the list" do
          em {
            user1 = Okey::User.new(FakeWebSocketClient.new({}))
            @lounge.join_lounge(user1)
            user1.websocket.get_onmessage.call((@create_json_attr).to_json) # create room

            @user.websocket.get_onmessage.call(@create_json_attr.to_json) # try to create second
            json = @user.websocket.sent_data
            parsed = JSON.parse(json)

            parsed["status"].should == "error"
            parsed["payload"]["message"].should == "room name is already taken"

            done
          }
        end

        it "should send an error json if the room field is nil or empty" do
          em {
            @user.websocket.get_onmessage.call((@create_json_attr.merge!({ :room_name => "" })).to_json)
            json = @user.websocket.sent_data
            parsed = JSON.parse(json)

            parsed["status"].should == "error"
            parsed["payload"]["message"].should == "room name cannot be empty"

            @user.websocket.sent_data = nil
            @create_json_attr.delete(:room_name)
            @user.websocket.get_onmessage.call(@create_json_attr.to_json)
            json = @user.websocket.sent_data
            parsed = JSON.parse(json)

            parsed["status"].should == "error"
            parsed["payload"]["message"].should == "room name cannot be empty"
            done
          }
        end

      end

    end
  end

end