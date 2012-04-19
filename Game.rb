class Game
	attr_accessor :players, :active_players, :state, :losers

	@start_x = [ 100, 180, 100, 20]
	@start_y = [ 20, 100, 180, 100]
	@start_dir = [ "north", "west", "south", "east"]

	def initialize(owner)
		@players = [ owner ]
		@active_players = [ owner ]
		@state = :OPEN
		@losers = 0
	end

	def add(new_player)
		if @state == :OPEN
			@players << new_player
			@active_players << new_player
		end
	end

	def enter_arena
		if @players.count == 2
			@players[0].socket.send({"enter_arena" =>
				{ "startPosition" => { "xStart" => 100, "yStart" => 20,
						"dirStart" => "north" }, "opponents" => 
				[{"xStart" => 100, "yStart" => 180, "dirStart" => "south"}]}}.to_json)
			@players[1].socket.send({"enter_arena" =>
				{ "startPosition" => { "xStart" => 100, "yStart" => 20,
						"dirStart" => "south" }, "opponents" => 
				[{"xStart" => 100, "yStart" => 180, "dirStart" => "south"}]}}.to_json)
		end
	end

	def start
		@players.each do |p|
			p.socket.send({"startGame" => true}.to_json)
		end	
	end

	def turn(json, player)
		index = @players.index player
		turnMess = json["turn"]
		turnMess["playerId"] = index
		@players.each do |p|
			unless p == player
				p.socket.send({"opponentTurn" => turnMess})
			end
		end
	end

	def loser(loser)
		@active_players.delete loser
		if @active_players.count = 1
			@active_players[0].socket.send({"gameResult" => {"result" => "win"}}.to_json)
			@players.each do |p|
				p.socket.send({"endGame" => true}.to_json)
			end
		end
	end
end
