require 'set'

class Player
	attr_accessor :state, :username, :inviter, :game, :socket

	@@usernames = Set.new

	def initialize(socket)
		@socket = socket
	end

	# Check for availability of username and log in
	def login(proposed_name)
		unless @@usernames.include? proposed_name
			@@usernames.add proposed_name
			@username = proposed_name
			return true
		end
		return false
	end

	def logout
		@@usernames.delete @username
	end

	def invite(inviter)
		@inviter = json["invitation"]["user"]
	end

	def send_invitation(username) 
		@inviter = username
		@socket.send({ "invitation" => { "user" => username }}.to_json)
	end

end
