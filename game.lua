
-- The main game object for tracking everything in Panel Attack.
-- Not to be confused with "Match" which is the current battle / instance of the game.
Game =
  class(
  function(self)
    self.scores = require("scores")
    self.match = nil -- the current match going on or nil if inbetween games
    self.focused = true -- if the window is focused
    self.backgroundImage = nil -- the background image for the game, should always be set to something with the proper dimensions
  end
)

local game = Game()

return game
