require 'eventmachine'
require 'em-websocket'
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
			player = @connections[ws]
			puts "Received #{mess} from #{player.username}"
			if parsed_mess.key? "logIn"
				if player.login(parsed_mess)
					puts "Sending loginResult success"
					player.socket.send({"loginResult"=>{"result"=>"success"}}.to_json)
					puts "Sending lobby"
					player.socket.send({ "lobby" => { "users" => @connections.values.map{|p| p.username}.compact }}.to_json)
					@connections.each_pair do |k,v| 
						k.send({"lobbyUpdate"=>{"entered"=>true, "user"=>player.username}}.to_json) unless v.username.nil? or v == player
					end
				else
					puts "Sending loginResult failure"
					player.socket.send({"loginResult"=>{"result"=>"failure"}}.to_json)
				end
			end
			if parsed_mess.key? "invitation"
				player.invite(parsed_mess)
			end
			if parsed_mess.key? "acceptInvitation"
				puts "Received an acceptance from #{player.username}"
				if @games.key? player.inviter
					puts "Inviter has an active game"
					@games[player.inviter].add player
					player.game = @games[player.inviter]
					player.state = :INVITATION_ACCEPTED
				else
					puts "#{player.inviter} does not have a game, #{player.username} cannot accept invitation"
				end	
			end
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
				unless player.game == nil
					player.game.loser(player)
				end
			end
		end

		ws.onclose do
			puts "Connection closed"
			@connections.each_pair do |k,v| 
				k.send({"lobbyUpdate"=>{"entered"=>false, "user"=>@connections[ws].username}}.to_json) unless v.username.nil?
				puts "Sending #{{"lobbyUpdate"=>{"entered"=>false, "user"=>@connections[ws].username}}.to_json} to #{v.username}" unless v.username.nil?
			end
			@connections[ws].logout
			@connections.delete(ws)
		end
	end

end

