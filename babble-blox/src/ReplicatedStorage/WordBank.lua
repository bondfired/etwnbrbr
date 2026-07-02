-- Prompt data and the describer's tappable clue-word pool.
--
-- Everything a player can send to the server is drawn from these fixed,
-- pre-approved lists (clue words for describers, multiple-choice options for
-- guessers). That's deliberate: it's the primary defense against Roblox's
-- unpredictable TextService filtering described in the roadmap, not a
-- fallback bolted on after the fact. Free-text guessing (with
-- TextService:FilterStringAsync) is a possible future addition, not part of
-- this first pass.

local WordBank = {}

WordBank.ClueWordPool = {
	"big", "small", "fast", "slow",
	"yellow", "blue", "red", "green",
	"scary", "funny", "cute", "loud",
	"quiet", "round", "square", "flying",
	"jumps", "runs", "swims", "eats",
	"plays", "shiny", "old", "new",
	"tiny", "huge", "strong", "weak",
	"furry", "sweet", "spicy", "crunchy",
}

-- Kid-friendly default pack per the roadmap: Roblox games, memes, animals, food.
WordBank.Prompts = {
	{ category = "Roblox Games", answer = "Adopt Me!", guessOptions = { "Adopt Me!", "Brookhaven", "Blox Fruits", "Tower of Hell" } },
	{ category = "Roblox Games", answer = "Blox Fruits", guessOptions = { "Blox Fruits", "Adopt Me!", "Pet Simulator", "Doors" } },
	{ category = "Animals", answer = "Elephant", guessOptions = { "Elephant", "Giraffe", "Rhino", "Hippo" } },
	{ category = "Animals", answer = "Penguin", guessOptions = { "Penguin", "Owl", "Duck", "Flamingo" } },
	{ category = "Food", answer = "Pizza", guessOptions = { "Pizza", "Burger", "Taco", "Sushi" } },
	{ category = "Food", answer = "Ice Cream", guessOptions = { "Ice Cream", "Cake", "Cookie", "Donut" } },
	{ category = "Memes", answer = "Rickroll", guessOptions = { "Rickroll", "Doge", "Among Us", "Skibidi Toilet" } },
	{ category = "Memes", answer = "Among Us", guessOptions = { "Among Us", "Rickroll", "Doge", "Ohio" } },
}

return WordBank
