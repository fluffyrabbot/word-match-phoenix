# Word Match Bot Game Mode Rules

This document outlines the rules, scoring systems, and win/loss conditions for each game mode in Word Match Bot.

## Common Game Logic (consistent across all modes)
- Team-based play (always 2 players per team) (always 2-12 teams in every mode except two player mode, which is a cooperative mode for 2 players)
- All word distribution and guess submission is handled in discord direct messages.
- A forbidden word list for each player (unique to each player) is initialized that holds an amount of elements set by a setting (default fallback 12), eliminating oldest elements first. Any valid guess that is not in the forbidden list is added to the list. The forbidden list persists across games.
- Teams always start each round with a guess count of 0, and always are given a new word pair by the word service. If either of the word pair is a repeat of a word from the forbidden list the team is given a new word pair (this process is not visible to the players). The words are added to the forbidden list for the duration of the round.
- Teams submit word guesses in pairs (both players on each team must guess before the stage advances). If they submit a word from the forbidden list, they are told that the word is invalid and must submit a new word.
- If the submitted guesses do not match, their differing guessed words are passed back to both of them as their new word pair, and their guess count for the stage increments. All valid guesses are recorded along with the time they were submitted and the player who submitted them.
- If the submitted guesses do match, the team is recorded as having achieved a match. The matched word and amount of guesses it took to achieve the match are recorded. The consequences of the match depend on game mode. 

## Common recordkeeping requirements
  - All valid guess pairs are recorded with timestamp, the players who submitted them (player:guess mapping must be maintained), the team they were submitted for, the words they guessed, the guess count at the time of submission, and the result of the guess (match or failed guess).
  - Win/loss by team and player is recorded at the end of every game with timestamp, game mode, and game parameters used.

## Knockout Mode
### Overview
Teams compete in rounds, with the slowest teams being eliminated until one team remains.

### Initial setup
- Teams are passed in from the game initialization system.
- A parameter for time limit per round is passed in from a settings file (default 3 minutes).
- A parameter for the number of guesses before automatic elimination is passed in from a settings file (default fallback 12 guesses to match, then automatically eliminated).
- As the game initializes, all teams are given a guess count of 0.

### Game logic
- The common game logic then applies. At the end of each round (end of round determined by all teams either matching or failing to match by the guess count limit), the team with the highest guess count is eliminated.
- If two teams tie for the highest guess count, they are both eliminated unless they are the last two teams.
- If three or more teams tie for the highest guess count, no teams are eliminated
- A discord embedded status update message is sent to the channel the game is in, announcing eliminated teams and guess counts of all teams.
- The round then restarts with the remaining teams after a 5 second delay (configurable).

### Win Condition
- Last team standing wins

## Golf Race Mode
### Overview
Teams compete to match words with the fewest guesses possible, like golf scoring, under a time limit (default 3 minutes, configurable).

### Game logic
- The common game logic applies.
- After each match, points are assigned according to the scoring system, and a new round immediately begins for the team that matched (rounds are not shared between teams).
- Teams play asynchronously, rewarding speed and efficiency.

### Scoring System
- 4 points: 1 guess
- 3 points: 2-4 guesses
- 2 points: 5-7 guesses
- 1 point: 8-10 guesses
- 0 points: 11+ guesses
- -1 point: Giving up on a round

### Win Condition
- Highest total points at the end of all rounds
- Tiebreaker based on lowest average guesses per match

## Longform Mode
### Overview
A multi-day game mode where teams compete over extended periods.

### Scoring & Gameplay
- Each round lasts 24 hours (configurable)
- The common game logic applies.
- No limit on guesses per round.

### Elimination Rules
- Teams with highest guess count at round end are eliminated
- If all teams tie in highest guess count, all tied teams are eliminated unless they are the only remaining teams.
- Each elimination is handled with an dramatic turnover sequence (implementation details pending).

### Win Condition
- Last team remaining wins

## Race Mode
### Overview
Teams race to complete matches as quickly as possible.

### Game logic
- The common game logic applies.
- After each match, and a new round immediately begins for the team that matched (rounds are not shared between teams).
- Teams play asynchronously, rewarding speed.

### Scoring System
- One point per successful match

### Gameplay Rules
- Fixed time limit per game (default 3 minutes, configurable)
- No elimination - all teams play until time expires

### Win Condition
- Most matches completed when time expires
- Tiebreaker based on lowest average guesses per match

## Two Player Mode
### Overview
Cooperative mode for two players working together.

### Game logic
- The common game logic applies.
- After each match, a new round immediately begins.

### Scoring System
- Success threshold: Average of 4 guesses per round or better (configurable)
- Perfect round: Match in first guess pair
- Points based on guess efficiency

### Gameplay Rules
- Fixed number of rounds (default 5, configurable)
- Both players must participate in matches
- No elimination - play all rounds

### Win Condition
- Team wins if average guesses across all rounds is below threshold
- Performance rating based on:
  - Number of perfect rounds
  - Average guesses per round
  - Total completion time