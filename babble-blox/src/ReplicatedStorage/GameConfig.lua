-- Shared constants for round pacing and scoring. Keep server and client
-- in agreement by requiring this from both sides rather than duplicating numbers.
return {
	MIN_PLAYERS = 3,
	MAX_PLAYERS = 8,

	INTRO_DURATION = 5,
	DESCRIBING_DURATION = 90,
	REVEAL_DURATION = 6,
	SCORING_DURATION = 4,

	MAX_CLUE_WORDS = 8,

	GUESS_POINTS_BASE = 100,
	DESCRIBER_POINTS_PER_CORRECT_GUESSER = 50,
}
