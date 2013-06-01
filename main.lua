--Settings

--graphics

FONT = love.graphics.newFont( "VeraMono.ttf", 24)

COLOURS = {
	DEFAULT = {0, 0, 0}, --black
	PLAYER = {27, 32, 167}, --blue
	TARGET = {0, 255, 127}, --green
	ENEMY = {238, 135, 66}, -- orange
	BASE = {236, 104, 216} --pink
	
}
DEFAULT_SCREEN_SIZE = {800, 800}
SCREEN_SCALE = {1.0, 0.75}

--space
WORLD_SIZE = {100, 100}
CENTRE = {WORLD_SIZE[1] /2 , WORLD_SIZE[2] /2}
BASE_RADIUS = WORLD_SIZE[1] * 0.2


--locations, period of enemy spawn (secs)
SPAWN_POINTS = {
	{0, WORLD_SIZE[2]},
	{WORLD_SIZE[1] / 2, 0},
	{WORLD_SIZE[1], WORLD_SIZE[2] / 2}
			
}
SPAWN_PERIOD = 15
SPAWN_SCALE_TIME = 2 * 60
SPAWN_PERIOD_END = 2

--Player settings
PLAYER_SPEED = 0.5
TARGET_SCORE = 100
FIRE_ARC = 30
FIRE_RANGE = 40
PLAYER_MAX_HP = 50

function love.keypressed(key, unicode)
	c = string.char(unicode)

if game_state == "GAME" then
	
	if key == 'return' then
		player:submit_input()
	elseif c:find("[%a%p%d ]") ~= nil then
		player.input = player.input .. c
		
	elseif key == 'backspace' then
	
		if player.input:len() > 1 then
			player.input = player.input:sub(1, player.input:len() -1)
		else
			player.input = ''
		end	
	end
else
	if key == 'r' then
		love.load()
	end
end

	if key == 'escape' then
		love.event.push("quit")
	end

end


function love.draw()
	local sw = love.graphics.getWidth()
	local sh = love.graphics.getHeight()

	--draw entities 
	player:draw()
	
	for _, e in ipairs(enemies) do
		e:draw()
	end
	
	--print score and typing section
	love.graphics.setColor(unpack(COLOURS.DEFAULT))
	love.graphics.rectangle("fill", 0, sh * SCREEN_SCALE[2], sw, sh * (1.0 - SCREEN_SCALE[2]))
	
	love.graphics.setColor(255, 255, 255)
	love.graphics.print("TO GO " .. (TARGET_SCORE - player.score), 20, sh * SCREEN_SCALE[2] + 24)
	love.graphics.print("HEALTH " .. player.hp, 20, sh * SCREEN_SCALE[2] + 80)  
	love.graphics.print(curr_word, sw/2, sh * SCREEN_SCALE[2] + 24)
	love.graphics.print(player.input, sw/2, sh * SCREEN_SCALE[2] + 80)
	
end

function love.update(dt)

if game_state == "GAME" then
	player:update(dt)
	
	for _,e in ipairs(enemies) do
		e:update(dt)
	end
	
	--increment time accumulators, add enemy or decrease period if necessary
	time_accum = time_accum + dt
	time_total = time_total + dt
	local period = SPAWN_PERIOD - (SPAWN_PERIOD - SPAWN_PERIOD_END) * (time_total / SPAWN_SCALE_TIME)
	
	period = math.max(period, SPAWN_PERIOD_END)
	
	if time_accum >= period then --make enemy
		e = Enemy:new()
		table.insert(enemies, e)
		time_accum = 0.0
	end
	
	--remove destroyed enemies
	
	for ent,_ in pairs(enemies_destroyed) do
	
		for i,e in ipairs(enemies) do
			if e == ent then
				table.remove(enemies, i)
				break
			end
		end
	
	end
	
	for k,_ in pairs(enemies_destroyed) do 
		enemies_destroyed[k] = nil
	end
end
end


function love.load()
	--graphics settings
	love.graphics.setMode(unpack(DEFAULT_SCREEN_SIZE))
	love.graphics.setCaption("TMT")
	love.graphics.setBackgroundColor(255, 255, 255)
	love.graphics.setFont(FONT)
	--model initialisation
	game_state = "GAME"
	thesaurus = {}
	load_thesaurus()
	curr_word_list = get_words()
	curr_word = curr_word_list[math.random(#curr_word_list)] 
	
	time_accum = 0.0
	time_total = 0.0
	
	player = Player:new()
	enemies = {}
	enemies_destroyed = {}
	
	base_hp = BASE_MAX_HP
end


--Player
Player = {}

function Player:new()
	local o = {
		rot = 0,
		score = 0,
		hp = PLAYER_MAX_HP,
		input = '', 
		ranges = {30, 48}
	} 	
	love.graphics.setPointSize(10)
	setmetatable(o, self)
	self.__index = self
	return o


end

function Player:update(dt)
	if self.score >= 100 then
		game_state = "VICTORY"
	end
	
end

function Player:draw()
	local sw = love.graphics.getWidth()
	love.graphics.setColor(unpack(COLOURS.DEFAULT))
	centre = world_to_screen(CENTRE[1], CENTRE[2])
	love.graphics.point(centre[1], centre[2])
	
	love.graphics.circle("line", centre[1], centre[2], self.ranges[1]/100 * sw * SCREEN_SCALE[2] )
	love.graphics.circle("line", centre[1], centre[2], self.ranges[2]/100 * sw * SCREEN_SCALE[2] )
	
end

function Player:submit_input()

	
	if self.input == curr_word then
		 self.input = ''
		 --attack
		 self:attack(1)
		 self.score = self.score + 1
		 
		curr_word_list = get_words()
		curr_word = curr_word_list[math.random(#curr_word_list)]
		return true
	else
		for _, w in ipairs(curr_word_list) do
			if self.input == w then --synonym sweep
			
				self.input = ''
				self:attack(2)
				self.score = self.score + 1
				
		curr_word_list = get_words()
		curr_word = curr_word_list[math.random(#curr_word_list)]
		return true
		
			end
		end
		
		return false
	end
end

function Player:hit()
	self.hp = self.hp - 1 
	
	if self.hp < 1 then
		game_state = "LOSS"
	end
end


function Player:attack(range)
		
	for _,e in ipairs(enemies) do
		if euclid(CENTRE[1], CENTRE[2], e.pos[1], e.pos[2]) <= e.size + self.ranges[range] then
			enemies_destroyed[e] = true
		end
	end
end


--Enemy
Enemy = {}

function Enemy:new()
	local spawni = math.random(#SPAWN_POINTS)
	spawn = {SPAWN_POINTS[spawni][1] + math.random(0, 2), SPAWN_POINTS[spawni][2] + math.random(0, 2)}
	
--	wts = world_to_screen(spawn[1], spawn[2])
--	love.graphics.setCaption("SPAWN: " .. spawn[1] .. ", " .. spawn[2] .. ' SCREEN:'..wts[1]..", "..wts[2])
	
	local o = {
		pos = {spawn[1], spawn[2]},
		size = 2.5,
		velocity = norm(CENTRE[1] - spawn[1], CENTRE[2] - spawn[2]),
		velocity_scale = 1.5
		
	} 	
	
	
	
	setmetatable(o, self)
	self.__index = self
	return o


end

function Enemy:update(dt)
	--move

	self.pos[1] = self.pos[1] + self.velocity[1] * self.velocity_scale * dt 
	self.pos[2] = self.pos[2] + self.velocity[2] * self.velocity_scale * dt
	
	--if an enemy reaches the base, it should be destroyed and deal damage
	if euclid(self.pos[1], self.pos[2], CENTRE[1], CENTRE[2]) < self.size + 10 then
		enemies_destroyed[self] = true 
		player:hit()
	end

end

function Enemy:draw()
	local sw = love.graphics.getWidth()
	
	local screen_pos = world_to_screen(self.pos[1], self.pos[2])
	
	love.graphics.setColor(unpack(COLOURS.ENEMY))
	love.graphics.circle("fill", screen_pos[1], screen_pos[2], self.size/WORLD_SIZE[1] * sw, 100)
end


--Thesaurus
function load_thesaurus()

	--load random thesaurus
	local filename = "thesaurus/mthesaur" .. math.random(0, 9) .. ".txt"
	local thesaurus_file = love.filesystem.newFile(filename)
	thesaurus_file:open('r')
	--obtain words from thesaurus, then close it
	for line in thesaurus_file:lines() do
		words = {}
		
		for w in string.gmatch(line, "[^%c,]+") do 
			table.insert(words, w)
		end
		
		table.insert(thesaurus, words)
		
	end
	
	thesaurus_file:close()
end

function get_words()
	--get inner table of synonyms from thesaurus, removing them 
	--to avoid repetition
	words = {}
	wordsi = math.random(#thesaurus)
	
	for _, w in ipairs(thesaurus[wordsi]) do
		table.insert(words, w)
	end
	
	table.remove(thesaurus, wordsi) 
	
	return words
end


--Mathsy


--converts world coordinates to a position on the screen 
function world_to_screen(x, y)
	local sw = love.graphics.getWidth()
	local sh = love.graphics.getHeight()

	res = {x/WORLD_SIZE[1] * sw * SCREEN_SCALE[1], (1.0 - y/WORLD_SIZE[2]) * sh * SCREEN_SCALE[2]}
	return res
end



--euclidean distance between two points 
function euclid(x0, x1, y0, y1)
	return magni(x0 - x1, y0 - y1)
end

function magni(x, y)
	return math.sqrt( math.pow( x, 2.0 ) + math.pow( y, 2.0 ) )
end

function norm(x, y)
	local mag = magni(x, y)
	return {x/mag, y/mag}
end
--canonical modulus
function canon_mod(n, m)
	return math.mod((math.mod(n, m) + m), m) 
end
