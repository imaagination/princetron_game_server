require 'eventmachine'
require 'em-websocket'
require 'sanitize'
require 'set'
require 'json'
require './Player'
require './Game'

@connections = {}
@games = {}

EventMachine.run do

	# Stupid Tron allusion
	puts "Starting the Grid"
	
	EventMachine::WebSocket.start(:host => '10.244.18.54', :port => 8080) do |ws|

		ws.onopen do
			puts "Received new connection"
			@connections[ws] = Player.new(ws)
		end

		ws.onmessage do |mess|
		  parsed_mess = JSON.parse(mess)
			# Determine who sent the message
			player = @connections[ws]
			puts "Received #{mess} from #{player.username}"
			# Determine message type
			if parsed_mess.key? "logIn"
				if parsed_mess["logIn"].key? "user" 
					proposed_name = parsed_mess["logIn"]["user"]
					# Invalid username
					if !/^[a-zA-Z0-9._]+$/.match(proposed_name)
						puts "Sending loginResult invalid"
						player.socket.send({"loginResult"=>{"result"=>"invalid"}}.to_json)
					# Successful login
					elsif player.username.nil? and player.login(proposed_name)
						puts "Sending loginResult success"
						player.socket.send({"loginResult"=>{"result"=>"success"}}.to_json)
						puts "Sending lobby"
						player.socket.send({ "lobby" => { "users" => @connections.values.map{|p| p.username}.compact }}.to_json)
						@connections.each_pair do |k,v| 
							k.send({"lobbyUpdate"=>{"entered"=>true, "user"=>player.username}}.to_json) unless v.username.nil? or v == player
						end
					# Duplicate username
					else
						puts "Sending loginResult duplicate"
						player.socket.send({"loginResult"=>{"result"=>"duplicate"}}.to_json)
					end
				end
			end
			if parsed_mess.key? "invitation"
				if parsed_mess["invitation"].key? "user"
					player.invite(parsed_mess["invitation"]["user"])
				end
			end
			if parsed_mess.key? "acceptInvitation"
				puts "Received an acceptance from #{player.username}"
				if @games.key? player.inviter
					puts "Inviter has an active game"
					@games[player.inviter].add player
					player.game = @games[player.inviter]
				else
					puts "#{player.inviter} does not have a game, #{player.username} cannot accept invitation"
				end	
			end
			# User is requesting the creation of a game
			if parsed_mess.key? "readyToPlay"
				if parsed_mess["readyToPlay"].key? "invitations"
					total_invites = parsed_mess["readyToPlay"]["invitations"].size
					@connections.each_value do |c|
						if parsed_mess["readyToPlay"]["invitations"].index(c.username) != nil
							puts "Sending invitation to #{c.username}"
							c.send_invitation(player.username)
						end
					end
				end
				puts "Opening a game for #{player.username}"
				@games[player.username] = Game.new(player, total_invites)
				player.game = @games[player.username]
				if @games.key? player.username
					puts "#{player.username} now has an open game"
				end
				EventMachine::Timer.new(5) do
					@games[player.username].invite_timeout
				end
			end
			if parsed_mess.key? "turn"
				player.game.turn(parsed_mess, player)
			end
			if parsed_mess.key? "collision"
				if parsed_mess["collision"].key? "timestamp"
					unless player.game == nil
						player.game.loser(player, parsed_mess["collision"]["timestamp"])
					end
				end
			end
			if parsed_mess.key? "chatSpeak"
				if !player.username.nil?
					if parsed_mess["chatSpeak"].key? "message"
						clean_message = Sanitize.clean(parsed_mess["chatSpeak"]["message"])
						@connections.each_key do |k|
							k.send({"chatHear"=>{"user"=>player.username, "message"=>clean_message}}.to_json)
						end
					end
				end
			end
		end

		ws.onclose do
			puts "Connection closed"
			# Notify all connected clients of logout
			@connections.each_pair do |k,v| 
				k.send({"lobbyUpdate"=>{"entered"=>false, "user"=>@connections[ws].username}}.to_json) unless v.username.nil?
				puts "Sending #{{"lobbyUpdate"=>{"entered"=>false, "user"=>@connections[ws].username}}.to_json} to #{v.username}" unless v.username.nil?
			end
			@connections[ws].logout
			@connections.delete(ws)
		end
	end

end

