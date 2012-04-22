class Player
	attr_accessor :state, :username, :inviter, :game, :socket

	def initialize(socket)
		@state = :NEW
		@socket = socket
	end

	def login(json)
		if @state == :NEW
			if json["logIn"].key? "user"
				@username = json["logIn"]["user"]
				@state = :IN_LOBBY	
			end
		end
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
