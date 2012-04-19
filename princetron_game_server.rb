require 'eventmachine'
require 'em-websocket'
require 'set'
require 'json'

@lobby_sockets = []
@player_games = {}

EventMachine.run do

	# Stupid Tron allusion
	puts "Starting the Grid"
	
	EventMachine::WebSocket.start(:host => '10.244.18.54', :port => 8080) do |ws|

		ws.onopen do
			puts "Received new connection"
		end

		ws.onmessage do |mess|
			puts "Received #{mess}"
		  parsed_mess = JSON.parse(mess)
			if parsed_mess.key? "readyToPlay"
				if @lobby_sockets.empty?
					puts "== Adding new player to lobby"
					@lobby_sockets << ws
				else
					puts "== Creating new game"
					s = Set.new [ ws, @lobby_sockets.shift]
					s.each { |p| @player_games[p] = s }
					s.each { |p| p.send({ "enterArena" => { "waitTime" => 0}}.to_json) }
				end
			end
			if parsed_mess.key? "turn"
				puts "== Received a turn message"
				new_mess = { "opponentTurn" => parsed_mess["turn"] }
				if @player_games.key? ws
					@player_games[ws].each do |s| 
						s.send new_mess.to_json unless ws == s
					end
				end
			end
			if parsed_mess.key? "collision"
				if @player_games.key? ws
					@player_games[ws].each do |s|
						s.send({ "endGame" => { "result" => "win" }}.to_json) unless ws == s
					end
	
					ws.send({ "endGame" => { "result" => "loss" }}.to_json)
				end
			end
		end

		ws.onclose do
			puts "Connection closed"
			@lobby_sockets.delete ws
		end
	end

end

