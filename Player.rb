require 'set'

class Player
	attr_accessor :state, :username, :inviter, :game, :socket

	@@usernames = Set.new

	def initialize(socket)
		@state = :NEW
		@socket = socket
	end

	def login(json)
		if @state == :NEW
			if json["logIn"].key? "user"
				proposed_name = json["logIn"]["user"]
				unless @@usernames.include? proposed_name
					@@usernames.add proposed_name
					@username = json["logIn"]["user"]
					@state = :IN_LOBBY	
					return true
				end
			end
		end
		return false
	end

	def logout
		@@usernames.delete @username
	end

	def invite(json)
		if @state == :IN_LOBBY
			if json["invitation"].key? "user"
				@inviter = json["invitation"]["user"]
				@state = :INVITED
			end
		end
	end

	def send_invitation(username) 
		@inviter = username
		@socket.send({ "invitation" => { "user" => username }}.to_json)
	end
end
