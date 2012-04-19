class Player
	attr_accessor :state, :username, :inviter, :game, :socket

	def initialize(socket)
		@state = :NEW
		@socket = socket
	end

	def login(json)
		if @state == :NEW
			if json["login"].key? "user"
				@username = json["login"]["user"]
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
		@socket.send({ "invitation" => { "user" => username }}.to_json)
	end
end
