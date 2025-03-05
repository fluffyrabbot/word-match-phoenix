## SpecStory

## Game Logic Edge Cases Analysis (3/4/2025, 5:04:21 PM)

_**User**_

@gamemoderules.md 

fully process this game logic. do you notice any edge cases that aren't properly handled?

---

_**Assistant**_

<think>
Okay, let's take a look at the user's question. They provided a game mode rules document and want to know if there are any unhandled edge cases.

First, I'll start by reading through the current file they provided. The document outlines several game modes with their rules and logic. My task is to identify potential edge cases or inconsistencies that aren't addressed.

Looking at the Common Game Logic section, I notice a few points. The forbidden list handling says that valid guesses not in the forbidden list are added. But what happens if the forbidden list is full? The default is 12 elements, and it eliminates the oldest. But when a new word is added, does it check if it's already present? The rules mention that if a word pair contains a forbidden word, it's replaced, but the process isn't visible. However, when a team submits a guess, if it's in the forbidden list, they're told it's invalid. But what if two players submit the same invalid word? Does each submission check the list, or is there a race condition? Maybe simultaneous submissions could cause issues.

Next, the Knockout Mode. The elimination rules state that the team with the highest guess count is eliminated. But if all teams have the same guess count, especially in the initial rounds, how is that handled? The document says if three or more teams tie, none are eliminated unless they're the last two. But if there are, say, four teams all with the same highest count, no elimination occurs. That might lead to endless rounds if teams keep tying. Also, the tiebreaker for the last two teams isn't specified—what if they tie in the final round?

In Golf Race Mode, the scoring system has points based on guess ranges. But what if a team reaches exactly 11 guesses? The scoring says 0 points for 11+, but the default guess limit in Knockout is 12. Is there a discrepancy here? Also, the -1 point for giving up: how does a team officially give up? The rules don't specify the mechanism for surrendering a round.

Longform Mode has 24-hour rounds. If a team doesn't submit any guesses, how are they handled? The elimination is based on highest guess count, but a team with zero guesses might have the lowest, but the rules don't address inactivity. There's a mention of a "dramatic turnover sequence" but no details on implementation, which could be a future problem.

Race Mode's win condition is most matches completed. If two teams have the same number of matches, the tiebreaker is average guesses. But what if the averages are also equal? There's no further tiebreaker mentioned, which could leave games unresolved.

Two Player Mode's win condition uses an average guess threshold. If the average is exactly the threshold, does it count as a win or loss? The document says "below threshold," so equality might not be handled. Also, the points based on efficiency aren't defined clearly—how are points calculated beyond the success threshold?

Other general issues: The document mentions forbidden lists persisting across games. Could this lead to players being penalized in future games for past actions? Also, team sizes are fixed at two players, but the initial setup allows 2-12 teams except for Two Player Mode. What if a team disconnects or leaves mid-game? The rules don't cover player dropouts or substitutions.

I should also check for consistency in configurable settings. For example, Knockout Mode has a default guess limit of 12, while Golf Race uses 11+ for 0 points. This might be intentional but could cause confusion. Additionally, some modes have time limits per round (Knockout) while others per game (Race). The terms "round" and "stage" might need clearer definitions to avoid ambiguity.

Lastly, the recordkeeping requirements mention tracking all guess pairs, but there's no mention of how data is stored or accessed for future reference, which could impact features like stats or leaderboards.
</think>

After analyzing the game mode rules, here are potential edge cases and inconsistencies that need addressing:

1. **Forbidden List Collisions**
```nodedocs/gamemoderules.md
// ... existing common logic ...
- Teams submit word guesses in pairs (both players on each team must guess before the stage advances). If they submit a word from the forbidden list, they are told that the word is invalid and must submit a new word.
// Missing handling for:
- Concurrent submissions adding words to forbidden lists before partner's submission
- Both players submitting different invalid words simultaneously
- Forbidden list reaching max capacity during a round
```

2. **Knockout Mode Elimination Logic**
```nodedocs/gamemoderules.md
// ... existing elimination rules ...
- If two teams tie for the highest guess count, they are both eliminated unless they are the last two teams.
// Needs clarification for:
- All teams having identical guess counts in first round
- Last 3 teams remaining with tied high scores
- Tiebreaker procedure for final two teams
```

3. **Golf Race Scoring Ambiguity**
```nodedocs/gamemoderules.md
// ... existing scoring ...
- 0 points: 11+ guesses
- -1 point: Giving up on a round
// Unaddressed scenarios:
- Team reaching exactly 12 guesses (matches Knockout default)
- Mechanism for "giving up" (how players signal surrender)
- Handling partial round progress after surrender
```

4. **Longform Mode Inactivity**
```nodedocs/gamemoderules.md
// ... existing rules ...
- No limit on guesses per round
// Missing provisions for:
- Teams making 0 guesses in a 24-hour period
- Server maintenance windows during longform games
- Player availability changes over multi-day periods
```

5. **Race Mode Tiebreakers**
```nodedocs/gamemoderules.md
// ... existing win condition ...
- Tiebreaker based on lowest average guesses per match
// Needs:
- Secondary tiebreaker for identical averages
- Handling of teams with equal matches and equal averages
```

6. **Two Player Mode Thresholds**
```nodedocs/gamemoderules.md
- Success threshold: Average of 4 guesses per round or better
// Ambiguities:
- Exact threshold handling (4.0 vs 3.9)
- Partial round completion if one player disconnects
- Scoring details for "points based on guess efficiency"

**Recommendations:**
1. Add validation for forbidden list synchronization between players
2. Define explicit tiebreaker hierarchies for all modes
3. Clarify surrender/abandonment mechanics
4. Specify inactivity timeouts for longform mode
5. Add secondary tiebreakers (e.g. timestamp of first match)
6. Quantify exact threshold comparisons

Would you like me to propose specific rule additions for any of these areas?

---

_**User**_

the forbidden list collisions concern is invalid: valid team-paired guess processes are the atomic unit of gameplay, the forbidden list should always drop oldest words live, and invalid word submissions are caught before they could be registered as valid guesses.

all teams having indentical guess counts would fit under the thre or more rule

last three teams remaining would fall under the no-elim if all elim'd rule

tthe tiebreaker concerns are valid, and fallback tiebreakers may be needed

---

_**Assistant**_

<think>
Okay, let me go through the user's response and make sure I address their points accurately.

First, the user clarified that forbidden list collisions aren't an issue because the team-paired guess process is atomic. They mentioned that invalid submissions are caught early, and the forbidden list updates in real-time by dropping the oldest entries. So, I need to retract that edge case as invalid based on their explanation.

Next, they pointed out that when all teams have identical guess counts, it falls under the three or more teams rule, meaning no elimination. Also, in the case of three remaining teams with tied high scores, the same rule applies. I should acknowledge that the existing rules handle these scenarios, so those points are resolved.

The user agreed that tiebreakers are a valid concern and that fallback mechanisms are needed. My task now is to focus on proposing specific tiebreaker rules for each game mode where ties could occur.

I'll start with Knockout Mode. The existing rules handle elimination when two teams are tied unless they're the last two. For the final two, a sudden death round makes sense. I should structure this as a numbered list of tiebreaker levels.

For Golf Race Mode, the primary tiebreaker is the lowest average guesses. The user mentioned needing a secondary tiebreaker, so I'll add the timestamp of the first match as the next level. If that's also tied, a sudden death round could be the final decider.

Race Mode's tiebreaker is similar to Golf Race, so applying the same structure there makes sense. Two Player Mode's success threshold needs a precise definition, so specifying that the average must be strictly less than 4.0 and adding tiebreakers based on perfect rounds and timestamps would cover it.

Longform Mode's elimination rules already handle most cases, but adding a timestamp-based tiebreaker for the final two teams ensures there's a clear winner. I should also note that all rules should be documented in the respective game mode sections.

Finally, I need to present these proposals clearly, asking if the user wants any adjustments or further details. Making sure the response is structured and addresses each game mode specifically will help the user implement the necessary changes.
</think>

Understood - let's focus on the valid tiebreaker concerns. Here are proposed specific rule additions:

**For Knockout Mode:**
```nodedocs/gamemoderules.md
// ... existing elimination rules ...
- Tiebreaker hierarchy for final two teams:
  1. Sudden death round with new word pair

---



---

