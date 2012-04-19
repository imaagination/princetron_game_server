require 'eventmachine'
require 'em-websocket'
require 'set'
require 'json'

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
			puts "Received #{mess}"
		  parsed_mess = JSON.parse(mess)
			player = @connections[ws]
			if parsed_mess.key? "login"
				player.login(parsed_mess)
			end
			if parsed_mess.key? "invitation"
				player.invite(parsed_mess)
			end
			if parsed_mess.key? "acceptInvitation"
				if @games.key? player.inviter
					@games[player.inviter].add player
					player.game = @games[player.inviter]
					player.state = :INVITATION_ACCEPTED
				end	
			end
			if parsed_mess.key? "readyToPlay"
				if parsed_mess.key? "invitations"
					@connections.each_value do |c|
						if parsed_mess["readyToPlay"]["invitations"].index(c) != nil
							c.send_invitation(player.username)
						end
					end
				end
				@games[player.username] = Game.new(player.username)
				EventMachine::Timer.new(10) do
					@games[player.username].enter_arena
					@games[player.username].start
				end
			end
			if parsed_mess.key? "turn"
				player.game.turn(parsed_mess, player)
			end
			if parsed_mess.key? "collision"
				player.game.loser(player)
				ws.send({ "endGame" => { "result" => "loss" }}.to_json)
			end
		end

		ws.onclose do
			puts "Connection closed"
			@lobby_sockets.delete ws
		end
	end

end

