class Game
	attr_accessor :players, :active_players, :state, :losers

	@start_x = [ 100, 180, 100, 20]
	@start_y = [ 20, 100, 180, 100]

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
			puts "#{@players[0].username} entering arena"
			@players[0].socket.send({"enterArena" => { 
				"playerId" => 0, "players" => 
				[{"xStart" => 25, "yStart" => 30, "dirStart" => "north"}, 
				 {"xStart" => 30, "yStart" => 25, "dirStart" => "east"}]}}.to_json)
			puts "#{@players[1].username} entering arena"
			@players[1].socket.send({"enterArena" => { 
				"playerId" => 1, "players" => 
				[{"xStart" => 25, "yStart" => 30, "dirStart" => "north"}, 
				 {"xStart" => 30, "yStart" => 25, "dirStart" => "east"}]}}.to_json)
		end
	end

	def start
		@players.each do |p|
			puts "#{p.username} starting game"
			p.socket.send({"startGame" => true}.to_json)
		end	
	end

	def invite_timeout
		if @players.size > 1
			self.enter_arena
			self.start
		end
	end

	def turn(json, player)
		index = @players.index player
		turnMess = json["turn"]
		turnMess["playerId"] = index
		@players.each do |p|
			unless p == player
				puts "Sending opponentTurn to #{p.username} with playerid #{turnMess["playerId"]} and isLeft of #{turnMess["isLeft"]}"
				p.socket.send({"opponentTurn" => turnMess}.to_json)
			end
		end
	end

	def loser(loser)
		index = @players.index loser
		@players.each do |p|
			p.socket.send({"gameResult" => 
				{ "playerId" => index, "result" => "loss"}}.to_json)
		end
		@active_players.delete loser
		if @active_players.length == 1
			winner_index = @players.index @active_players[0]
			@players.each do |p|
				p.socket.send({"gameResult" => 
					{ "playerId" => winner_index, "result" => "win"}}.to_json)
				p.socket.send({"endGame" => true}.to_json)
			end
		end
	end
end
