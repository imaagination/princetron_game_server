require 'httparty'

class Game
	attr_accessor :players, :num_invites, :accepted_invites, :active_players, :state, :losers

	@start_x = [ 100, 180, 100, 20]
	@start_y = [ 20, 100, 180, 100]

	def initialize(owner, total_invites)
		@players = [ owner ]
		@active_players = [ owner ]
		@state = :OPEN
		@losers = 0
		@num_invites = total_invites
		@accepted_invites = 0
	end

	# Add a player to this game
	def add(new_player)
		if @state == :OPEN
			@players << new_player
			@active_players << new_player
			@accepted_invites += 1
			if @accepted_invites == @num_invites
				self.invite_timeout
			end	
		end
	end

	# Send specification for game to all players in game
	def enter_arena
		if @state == :OPEN
			if @players.count == 2
				game_spec =[{"xStart" => 25, "yStart" => 30, 
											"dirStart" => "north",
											"user" => @players[0].username}, 
				 						{"xStart" => 30, "yStart" => 25, 
											"dirStart" => "east",
											"user" => @players[1].username}]
			elsif @players.count == 3
				game_spec =[{"xStart" => 25, "yStart" => 25, 
											"dirStart" => "north",
											"user" => @players[0].username}, 
				 						{"xStart" => 75, "yStart" => 25, 
											"dirStart" => "north",
											"user" => @players[1].username},
										{"xStart" => 50, "yStart" => 75,
											"dirStart" => "south",
											"user" => @players[2].username}]
			elsif @players.count == 4
				game_spec =[{"xStart" => 25, "yStart" => 30, 
											"dirStart" => "north",
											"user" => @players[0].username}, 
				 						{"xStart" => 30, "yStart" => 25, 
											"dirStart" => "east",
											"user" => @players[1].username},
										{"xStart" => 75, "yStart" => 70,
											"dirStart" => "south",
											"user" => @players[2].username},
										{"xStart" => 70, "yStart" => 75,
											"dirStart" => "west",
											"user" => @players[3].username}]
			elsif @players.count == 5
				game_spec =[{"xStart" => 16, "yStart" => 25, 
											"dirStart" => "north",
											"user" => @players[0].username}, 
				 						{"xStart" => 32, "yStart" => 75, 
											"dirStart" => "south",
											"user" => @players[1].username},
										{"xStart" => 50, "yStart" => 25,
											"dirStart" => "north",
											"user" => @players[2].username},
										{"xStart" => 68, "yStart" => 75,
											"dirStart" => "south",
											"user" => @players[3].username},
										{"xStart" => 84, "yStart" => 25,
											"dirStart" => "north",
											"user" => @players[4].username}]
			elsif @players.count == 6
				game_spec =[{"xStart" => 16, "yStart" => 75, 
											"dirStart" => "south",
											"user" => @players[0].username}, 
				 						{"xStart" => 50, "yStart" => 75, 
											"dirStart" => "south",
											"user" => @players[1].username},
										{"xStart" => 84, "yStart" => 75,
											"dirStart" => "south",
											"user" => @players[2].username},
										{"xStart" => 16, "yStart" => 25,
											"dirStart" => "north",
											"user" => @players[3].username},
										{"xStart" => 50, "yStart" => 25,
											"dirStart" => "north",
											"user" => @players[4].username},
										{"xStart" => 84, "yStart" => 25,
											"dirStart" => "north",
											"user" => @players[5].username}]
			end
			@players.each_with_index do |p,i|
				puts "#{p.username} entering arena"
				p.socket.send({"enterArena"=>{"playerId"=>i, 
					"players"=>game_spec}}.to_json)
			end 
		end
		@state = :READY
	end

	# Tell clients to start game
	def start
		if @state == :READY
			@players.each do |p|
				puts "#{p.username} starting game"
				p.socket.send({"startGame" => true}.to_json)
			end	
			@state = :PLAYING
		end
	end

	# Notify client that nobody wants to play with them (loner)
	def invite_rejected
		@players[0].socket.send({"inviteRejected"=>true}.to_json)		
		@state = :CLOSED
	end

	# Triggered by invitation timeout
	def invite_timeout
		if @state == :OPEN
			if @players.size > 1
				self.enter_arena
				EventMachine::Timer.new(1) do
					self.start
			  end
			else 
				self.invite_rejected
			end
		end
	end

	# Notify opponents of turns
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

	# Handle players losing
	def loser(loser, timestamp)
		if @state == :PLAYING
			index = @players.index loser
			@players.each do |p|
				p.socket.send({"gameResult" => 
					{ "playerId" => index, "result" => "loss", "timestamp" => timestamp}}.to_json)
			end
			@active_players.delete loser
			@active_players.compact!
			if @active_players.length == 1
				@state = :CLOSED
				winner_index = @players.index @active_players[0]
				@players.each do |p|
					p.socket.send({"gameResult" => 
						{ "playerId" => winner_index, "result" => "win"}}.to_json)
					p.socket.send({"endGame" => true}.to_json)
				end
				# Report result to metagame
				puts "Reporting result"
				winner = @players[winner_index]
				losers = Array.new(@players)
				losers.delete_at winner_index
				losers.compact!
				cur_time = Time.now.strftime("%m/%d/%Y:%H:%M:%S")
				options = { :body => {:time => cur_time, :winner => winner.username, :losers => losers.map{|p| p.username}.join(',') } }
				HTTParty.post("http://www.princetron.com/game/", options)
			end
		end
	end
end
