const BaseMode = require('./baseMode');
const { createError, ErrorCodes } = require('../utils/errorHandler');
const logger = require('../utils/logger');
const performanceMonitor = require('../utils/performanceMonitor');
const { EVENT_TYPES, GameEvent, DOMAINS, ACTIONS } = require('../utils/eventRegistry');
const { EmbedBuilder } = require('discord.js');
const TableFormatter = require('../utils/tableFormatter');
const embedHelper = require('../utils/embedHelper');
const ModeStatsHelper = require('../utils/modeStatsHelper');
const { Mutex } = require('../utils/mutex');
const { v4: uuidv4 } = require('uuid');

// Define the TwoPlayerMode event types if they don't exist
if (!EVENT_TYPES.MODE.TWO_PLAYER) {
    EVENT_TYPES.MODE.TWO_PLAYER = {
        INITIALIZED: `${DOMAINS.MODE}.twoPlayer.${ACTIONS.INITIALIZED}`,
        STARTED: `${DOMAINS.MODE}.twoPlayer.${ACTIONS.STARTED}`,
        ENDED: `${DOMAINS.MODE}.twoPlayer.${ACTIONS.ENDED}`,
        ROUND: {
            STARTED: `${DOMAINS.MODE}.twoPlayer.round.${ACTIONS.STARTED}`,
            ENDED: `${DOMAINS.MODE}.twoPlayer.round.${ACTIONS.ENDED}`
        },
        GUESS: {
            RECORDED: `${DOMAINS.MODE}.twoPlayer.guess.${ACTIONS.RECORDED}`,
            REJECTED: `${DOMAINS.MODE}.twoPlayer.guess.rejected`,
            FAILED: `${DOMAINS.MODE}.twoPlayer.guess.failed`
        },
        MATCH: {
            FOUND: `${DOMAINS.MODE}.twoPlayer.match.found`
        },
        TEAM: {
            SUCCESS: `${DOMAINS.MODE}.twoPlayer.team.success`,
            FAILURE: `${DOMAINS.MODE}.twoPlayer.team.failure`
        }
    };
}

class TwoPlayerMode extends BaseMode {
    static REQUIRED_PLAYERS = 2;
    static TOTAL_ROUNDS = 5;
    static DEFAULT_WIN_THRESHOLD = 4; // Average guesses per round threshold for success
    static GAME_REGISTRY = new Map(); // Registry to track all active Two-Player game instances

    /**
     * Get a list of all active Two-Player game instances
     * @returns {Array<string>} Array of game instance IDs
     */
    static getActiveGameInstances() {
        return Array.from(TwoPlayerMode.GAME_REGISTRY.keys());
    }

    /**
     * Get a Two-Player game instance by ID
     * @param {string} instanceId - The game instance ID
     * @returns {TwoPlayerMode|null} The game instance or null if not found
     */
    static getGameInstance(instanceId) {
        return TwoPlayerMode.GAME_REGISTRY.get(instanceId);
    }
    
    /**
     * Create a unique game instance ID
     * @returns {string} A unique game instance ID
     */
    static generateGameInstanceId() {
        return `2p-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    }

    /**
     * Get all active Two-Player game instances for a server
     * @param {string} serverId - The server ID
     * @returns {Array<TwoPlayerMode>} Array of game instances
     */
    static getServerGameInstances(serverId) {
        return Array.from(TwoPlayerMode.GAME_REGISTRY.values())
            .filter(instance => instance.serverId === serverId);
    }

    /**
     * Check if a player is already in an active Two-Player game
     * @param {string} playerId - The player ID to check
     * @returns {string|null} The game instance ID the player is in, or null if not in a game
     */
    static findPlayerGame(playerId) {
        for (const [instanceId, game] of TwoPlayerMode.GAME_REGISTRY.entries()) {
            if (game.players.includes(playerId)) {
                return instanceId;
            }
        }
        return null;
    }

    constructor(options = {}) {
        super(options);
        // Ensure serverId and channelId are explicitly set from options
        this.serverId = options.serverId || this.serverId || 'unknownServer';
        this.channelId = options.channelId || this.channelId || 'unknownChannel';
        this.winThreshold = options.winThreshold || TwoPlayerMode.DEFAULT_WIN_THRESHOLD;
        
        // Set the game instance ID
        this.gameInstanceId = options.gameInstanceId || TwoPlayerMode.generateGameInstanceId();
        
        // Initialize mutex for thread safety
        this.mutex = new Mutex();
        
        // Store players for quick lookup
        this.players = options.players || [];
        
        // Register this instance in the global registry
        TwoPlayerMode.GAME_REGISTRY.set(this.gameInstanceId, this);
        
        // Add logging context
        this.loggingContext = {
            ...this.loggingContext,
            gameInstanceId: this.gameInstanceId
        };
        
        logger.info(`Two-Player game instance created with ID: ${this.gameInstanceId}`, this.loggingContext);
        
        // Initialize stats helper
        this.statsHelper = new ModeStatsHelper(this.gameState);
        
        // Initialize game state with setters to track dirty flags
        this.gameState.setMode(BaseMode.GAME_MODES.TWO_PLAYER);
        this.gameState.setState('pending');
        this.gameState.setRound(0);
        this.gameState.setPlayers([]);
        this.gameState.setTeam({ id: 'team1', members: [], guesses: [], roundsCompleted: 0, roundResults: [] });
        this.gameState.setCurrentRound(null);
        this.gameState.setStartTime(null);
        this.gameState.setMatchId(null);

        // Initialize replay data structure with cooperative metrics
        this.replayData = {
            metadata: {
                mode: BaseMode.GAME_MODES.TWO_PLAYER,
                startTime: Date.now(),
                serverId: this.serverId,
                channelId: this.channelId,
                gameInstanceId: this.gameInstanceId,
                twoPlayerSpecific: {
                    winThreshold: this.winThreshold,
                    roundHistory: [],
                    performanceMetrics: {
                        averageGuessesPerRound: 0,
                        perfectRounds: 0,
                        totalGuesses: 0,
                        bestRound: null,
                        worstRound: null
                    }
                }
            },
            rounds: []
        };

        // Initialize current round data structure
        this.currentRoundData = {
            roundNumber: 0,
            startTime: null,
            words: [],
            guesses: [],
            teamGuessCount: 0,
            matched: false,
            endTime: null
        };

        this.logModeEvent(EVENT_TYPES.MODE.TWO_PLAYER.INITIALIZED, {
            metadata: {
                totalRounds: TwoPlayerMode.TOTAL_ROUNDS,
                winThreshold: this.winThreshold,
                requiredPlayers: TwoPlayerMode.REQUIRED_PLAYERS,
                gameInstanceId: this.gameInstanceId
            }
        });
    }

    async logTwoPlayerEvent(event, data = {}) {
        if (!(event in EVENT_TYPES.MODE.TWO_PLAYER)) {
            throw createError('Invalid two-player event type', ErrorCodes.INVALID_EVENT_TYPE, {
                event,
                validEvents: Object.keys(EVENT_TYPES.MODE.TWO_PLAYER)
            });
        }

        await this.logModeEvent(event, {
            mode: BaseMode.GAME_MODES.TWO_PLAYER,
            round: this.gameState?.round,
            playerCount: this.gameState?.players?.length,
            teamId: this.gameState?.team?.id,
            ...data
        });
    }

    async logTwoPlayerError(error, context = {}) {
        await this.logModeError(error, {
            mode: BaseMode.GAME_MODES.TWO_PLAYER,
            round: this.gameState?.round,
            playerCount: this.gameState?.players?.length,
            teamId: this.gameState?.team?.id,
            ...context
        });
    }

    async start(options = {}) {
        const startTime = Date.now();
        try {
            // Validate player count
            if (!options.players || options.players.length !== TwoPlayerMode.REQUIRED_PLAYERS) {
                throw createError(
                    'Two-player mode requires exactly 2 players',
                    ErrorCodes.INVALID_PLAYER_COUNT,
                    {
                        required: TwoPlayerMode.REQUIRED_PLAYERS,
                        provided: options.players?.length
                    }
                );
            }

            // Set initial game state using setters to track dirty flags
            this.gameState.setState('active');
            this.gameState.setPlayers(options.players);
            this.gameState.setRound(0);
            this.gameState.setMatchId(options.matchId || Date.now().toString(36));
            this.gameState.setStartTime(Date.now());
            
            // Set up team with both players
            const team = {
                id: 'team1',
                name: 'Cooperative Team',
                members: options.players.map(p => p.id),
                guesses: [],
                roundsCompleted: 0,
                roundResults: []
            };
            this.gameState.setTeam(team);

            // Start first round
            await this.startNewRound();

            // Save state after all modifications
            await this.gameState.saveState();

            await this.logTwoPlayerEvent(EVENT_TYPES.MODE.TWO_PLAYER.STARTED, {
                duration: Date.now() - startTime,
                metadata: {
                    matchId: this.gameState.matchId,
                    players: this.gameState.players.map(p => p.id),
                    totalRounds: TwoPlayerMode.TOTAL_ROUNDS,
                    winThreshold: this.winThreshold
                }
            });

            return {
                matchId: this.gameState.matchId,
                status: 'started',
                players: this.gameState.players,
                currentRound: this.gameState.currentRound,
                totalRounds: TwoPlayerMode.TOTAL_ROUNDS
            };
        } catch (error) {
            await this.logTwoPlayerError(error, {
                context: 'start_game',
                duration: Date.now() - startTime,
                metadata: { options }
            });
            throw error;
        }
    }

    async startNewRound() {
        const startTime = Date.now();
        try {
            // Check if we've reached the total number of rounds
            if (this.gameState.round >= TwoPlayerMode.TOTAL_ROUNDS) {
                return await this.endGame('complete');
            }

            const words = await this.wordManager.getRandomWords(2);

            // Create new round data
            this.currentRoundData = {
                roundNumber: this.gameState.round + 1,
                startTime: Date.now(),
                words,
                guesses: [],
                teamGuessCount: 0,
                matched: false
            };

            // Update game state using setters
            this.gameState.setRound(this.gameState.round + 1);
            this.gameState.setCurrentRound(this.currentRoundData);
            this.gameState._dirtyFlags.currentRound = true;

            await this.logTwoPlayerEvent(EVENT_TYPES.MODE.TWO_PLAYER.ROUND.STARTED, {
                duration: Date.now() - startTime,
                metadata: {
                    round: this.gameState.round,
                    totalRounds: TwoPlayerMode.TOTAL_ROUNDS,
                    wordCount: words.length,
                    teamMembers: this.gameState.team.members
                }
            });

            // Save state after modifications
            await this.gameState.saveState();

            return this.getCurrentRoundState();
        } catch (error) {
            await this.logTwoPlayerError(error, {
                context: 'start_round',
                duration: Date.now() - startTime,
                metadata: {
                    round: this.gameState.round + 1
                }
            });
            throw error;
        }
    }

    getCurrentRoundState() {
        if (!this.currentRoundData) {
            throw createError('No active round', ErrorCodes.INVALID_GAME_STATE);
        }

        return {
            roundNumber: this.currentRoundData.roundNumber,
            totalRounds: TwoPlayerMode.TOTAL_ROUNDS,
            words: this.currentRoundData.words,
            guessCount: this.currentRoundData.teamGuessCount,
            team: this.gameState.team,
            display: TableFormatter.formatRoundTable(this.currentRoundData)[0]
        };
    }

    async processGuess(playerId, guess) {
        const startTime = Date.now();
        try {
            // Use mutex to ensure thread safety
            const release = await this.mutex.acquire();
            
            try {
                // Validate game state
                if (this.gameState.status !== 'active') {
                    await this.logTwoPlayerEvent(EVENT_TYPES.MODE.TWO_PLAYER.GUESS.REJECTED, {
                        playerId,
                        reason: 'game_not_active',
                        metadata: { status: this.gameState.status }
                    });
                    throw createError(
                        'Game is not active',
                        ErrorCodes.INVALID_GAME_STATE,
                        { status: this.gameState.status }
                    );
                }

                // Validate player is in the game
                if (!this.gameState.players.find(p => p.id === playerId)) {
                    await this.logTwoPlayerEvent(EVENT_TYPES.MODE.TWO_PLAYER.GUESS.REJECTED, {
                        playerId,
                        reason: 'player_not_in_game'
                    });
                    throw createError(
                        'Player is not in this game',
                        ErrorCodes.INVALID_PLAYER,
                        { playerId }
                    );
                }

                // Record guess
                const guessData = {
                    playerId,
                    guess: guess.toLowerCase(),
                    timestamp: Date.now()
                };
                this.currentRoundData.guesses.push(guessData);
                this.gameState.team.guesses.push(guessData);
                this.gameState._dirtyFlags.currentRound = true;
                this.gameState._dirtyFlags.team = true;

                // Track team guesses (pairs of guesses)
                if (this.currentRoundData.guesses.length % 2 === 0) {
                    this.currentRoundData.teamGuessCount++;
                }

                await this.logTwoPlayerEvent(EVENT_TYPES.MODE.TWO_PLAYER.GUESS.RECORDED, {
                    playerId,
                    duration: Date.now() - startTime,
                    metadata: {
                        guess: guessData.guess,
                        round: this.gameState.round,
                        guessCount: this.currentRoundData.guesses.length,
                        teamGuessCount: this.currentRoundData.teamGuessCount
                    }
                });

                // Check for match if we have two guesses
                if (this.currentRoundData.guesses.length >= 2) {
                    const lastTwo = this.currentRoundData.guesses.slice(-2);
                    const matchResult = await this.wordManager.matchWords(
                        lastTwo[0].guess,
                        lastTwo[1].guess
                    );

                    if (matchResult.matched) {
                        // Update round data
                        this.currentRoundData.matched = true;
                        this.currentRoundData.endTime = Date.now();

                        // Update team data
                        const roundResult = {
                            roundNumber: this.gameState.round,
                            guessCount: this.currentRoundData.teamGuessCount,
                            individualGuessCount: this.currentRoundData.guesses.length,
                            duration: this.currentRoundData.endTime - this.currentRoundData.startTime,
                            matched: true,
                            words: this.currentRoundData.words,
                            guesses: this.currentRoundData.guesses
                        };
                        this.gameState.team.roundsCompleted++;
                        this.gameState.team.roundResults.push(roundResult);
                        this.gameState._dirtyFlags.team = true;

                        // Update replay data
                        this.replayData.rounds.push({
                            ...this.currentRoundData,
                            roundResult
                        });

                        // Update performance metrics
                        this.updatePerformanceMetrics(roundResult);

                        await this.logTwoPlayerEvent(EVENT_TYPES.MODE.TWO_PLAYER.MATCH.FOUND, {
                            playerId,
                            duration: Date.now() - startTime,
                            metadata: {
                                round: this.gameState.round,
                                totalRounds: TwoPlayerMode.TOTAL_ROUNDS,
                                guessCount: this.currentRoundData.guesses.length,
                                guesses: lastTwo.map(g => g.guess),
                                roundDuration: roundResult.duration,
                                metrics: this.replayData.metadata.twoPlayerSpecific.performanceMetrics
                            }
                        });

                        // Start new round or end game if we've completed all rounds
                        if (this.gameState.round >= TwoPlayerMode.TOTAL_ROUNDS) {
                            await this.endGame('complete');
                        } else {
                            await this.startNewRound();
                        }
                    } else {
                        await this.logTwoPlayerEvent(EVENT_TYPES.MODE.TWO_PLAYER.GUESS.FAILED, {
                            playerId,
                            duration: Date.now() - startTime,
                            metadata: {
                                round: this.gameState.round,
                                guesses: lastTwo.map(g => g.guess)
                            }
                        });
                    }
                }

                // Save state after modifications
                await this.gameState.saveState();

                return {
                    valid: true,
                    matched: this.currentRoundData.matched,
                    guessCount: this.currentRoundData.teamGuessCount,
                    individualGuessCount: this.currentRoundData.guesses.length,
                    round: this.gameState.round,
                    totalRounds: TwoPlayerMode.TOTAL_ROUNDS,
                    display: TableFormatter.formatRoundTable(this.currentRoundData)[0]
                };
            } finally {
                // Always release the mutex
                release();
            }
        } catch (error) {
            await this.logTwoPlayerError(error, {
                context: 'process_guess',
                playerId,
                duration: Date.now() - startTime,
                metadata: { guess }
            });
            throw error;
        }
    }

    updatePerformanceMetrics(roundResult) {
        const metrics = this.replayData.metadata.twoPlayerSpecific.performanceMetrics;
        
        // Update totals
        metrics.totalGuesses += roundResult.guessCount;
        metrics.perfectRounds += roundResult.guessCount === 1 ? 1 : 0;
        
        // Calculate new average
        const completedRounds = this.gameState.team.roundResults.length;
        metrics.averageGuessesPerRound = metrics.totalGuesses / completedRounds;
        
        // Track best round (lowest guess count)
        if (!metrics.bestRound || roundResult.guessCount < metrics.bestRound.guessCount) {
            metrics.bestRound = {
                roundNumber: roundResult.roundNumber,
                guessCount: roundResult.guessCount,
                words: roundResult.words
            };
        }
        
        // Track worst round (highest guess count)
        if (!metrics.worstRound || roundResult.guessCount > metrics.worstRound.guessCount) {
            metrics.worstRound = {
                roundNumber: roundResult.roundNumber,
                guessCount: roundResult.guessCount,
                words: roundResult.words
            };
        }
        
        return metrics;
    }

    calculateAverageGuesses() {
        const completedRounds = this.gameState.team.roundResults.length;
        if (completedRounds === 0) return 0;
        
        const totalGuesses = this.gameState.team.roundResults.reduce((sum, round) => sum + round.guessCount, 0);
        return totalGuesses / completedRounds;
    }

    isSuccessful() {
        const avgGuesses = this.calculateAverageGuesses();
        return avgGuesses > 0 && avgGuesses <= this.winThreshold;
    }

    async endGame(reason = 'complete') {
        const startTime = Date.now();
        try {
            // Set game state to completed
            this.gameState.setState('completed');
            this.gameState.setEndReason(reason);
            this.gameState.setEndTime(Date.now());

            // Calculate final metrics
            const avgGuesses = this.calculateAverageGuesses();
            const isSuccess = this.isSuccessful();
            const gameDuration = this.gameState.endTime - this.gameState.startTime;
            
            // Update replay data
            this.replayData.metadata.endTime = this.gameState.endTime;
            this.replayData.metadata.duration = gameDuration;
            this.replayData.metadata.success = isSuccess;
            this.replayData.metadata.averageGuesses = avgGuesses;
            this.replayData.metadata.endReason = reason;
            this.replayData.metadata.completedRounds = this.gameState.team.roundsCompleted;

            // Save replay
            await this.saveReplay();
            
            // Create team data structure for stats tracking
            const teamResults = [{
                id: this.gameState.team.id,
                name: 'Cooperative Team',
                members: this.gameState.team.members,
                score: isSuccess ? 1 : 0,
                active: true,
                guessCount: this.replayData.metadata.twoPlayerSpecific.performanceMetrics.totalGuesses,
                stats: {
                    avgGuesses: avgGuesses,
                    success: isSuccess,
                    perfectRounds: this.replayData.metadata.twoPlayerSpecific.performanceMetrics.perfectRounds,
                    completedRounds: this.gameState.team.roundsCompleted
                }
            }];
            
            // Save match stats using stats helper
            try {
                if (this.statsHelper) {
                    await this.statsHelper.saveMatchStats({
                        success: isSuccess,
                        averageGuesses: avgGuesses,
                        gameDuration,
                        teamResults
                    });
                } else {
                    logger.warn('No stats helper available for TwoPlayerMode');
                }
            } catch (statsError) {
                logger.error('Failed to save match stats', {
                    error: statsError,
                    matchId: this.gameState.matchId
                });
            }

            // Log appropriate team event based on success/failure
            const teamEventType = isSuccess 
                ? EVENT_TYPES.MODE.TWO_PLAYER.TEAM.SUCCESS 
                : EVENT_TYPES.MODE.TWO_PLAYER.TEAM.FAILURE;
                
            await this.logTwoPlayerEvent(teamEventType, {
                duration: Date.now() - startTime,
                metadata: {
                    avgGuesses: avgGuesses,
                    threshold: this.winThreshold,
                    completedRounds: this.gameState.team.roundsCompleted
                }
            });

            // Log game end event
            await this.logTwoPlayerEvent(EVENT_TYPES.MODE.TWO_PLAYER.ENDED, {
                duration: Date.now() - startTime,
                metadata: {
                    success: isSuccess,
                    reason,
                    gameDuration,
                    totalRounds: TwoPlayerMode.TOTAL_ROUNDS,
                    completedRounds: this.gameState.team.roundsCompleted,
                    averageGuesses: avgGuesses,
                    playerCount: this.gameState.players.length
                }
            });

            // Cleanup
            await this.cleanup();

            // Prepare game over UI data
            const metrics = this.replayData.metadata.twoPlayerSpecific.performanceMetrics;
            const totalMatchTime = this.gameState.endTime - this.gameState.startTime;
            
            // Two Player mode specific data for the embed
            const modeSpecificData = {
                fields: []
            };
            
            // Add success/failure header
            if (isSuccess) {
                modeSpecificData.fields.push({
                    name: '🎉 Success! Your team worked efficiently.',
                    value: `Average guesses: ${avgGuesses.toFixed(1)}\nThreshold: ${this.winThreshold}`,
                    inline: false
                });
            } else {
                modeSpecificData.fields.push({
                    name: '💔 Your team needs more practice...',
                    value: `Average guesses: ${avgGuesses.toFixed(1)}\nThreshold: ${this.winThreshold}`,
                    inline: false
                });
            }
            
            // Add team information
            modeSpecificData.fields.push({
                name: '👥 Team',
                value: this.gameState.players.map(p => `<@${p.id}>`).join(', '),
                inline: false
            });
            
            // Add performance stats
            if (metrics.bestRound) {
                modeSpecificData.fields.push({
                    name: '⚡ Best Round',
                    value: `Round ${metrics.bestRound.roundNumber}: ${metrics.bestRound.guessCount} guesses`,
                    inline: true
                });
            }
            
            if (metrics.perfectRounds > 0) {
                modeSpecificData.fields.push({
                    name: '✨ Perfect Rounds',
                    value: `${metrics.perfectRounds} of ${this.gameState.team.roundsCompleted}`,
                    inline: true
                });
            }
            
            // Add round-by-round breakdown
            if (this.gameState.team.roundResults.length > 0) {
                const roundBreakdown = this.gameState.team.roundResults
                    .map(r => `Round ${r.roundNumber}: ${r.guessCount} guesses`)
                    .join('\n');
                    
                modeSpecificData.fields.push({
                    name: '📊 Round Breakdown',
                    value: roundBreakdown,
                    inline: false
                });
            }
            
            // Create the standardized embed with our cooperative data
            const gameOverEmbed = embedHelper.createStandardGameOverEmbed(
                this.gameState, 
                [{ 
                    id: this.gameState.team.id, 
                    name: 'Cooperative Team',
                    members: this.gameState.players.map(p => p.id),
                    success: isSuccess,
                    avgGuesses: avgGuesses
                }], 
                totalMatchTime,
                modeSpecificData
            );

            // Prepare final results
            const finalStats = {
                status: 'completed',
                success: isSuccess,
                averageGuesses: avgGuesses,
                threshold: this.winThreshold,
                completedRounds: this.gameState.team.roundsCompleted,
                totalRounds: TwoPlayerMode.TOTAL_ROUNDS,
                duration: gameDuration,
                reason
            };

            // Return result with channelMessage for standardized handling
            return {
                ...finalStats,
                channelMessage: { embeds: [gameOverEmbed] }
            };
        } catch (error) {
            await this.logTwoPlayerError(error, {
                context: 'end_game',
                duration: Date.now() - startTime,
                metadata: {
                    reason,
                    round: this.gameState.round
                }
            });
            throw error;
        }
    }

    /**
     * Clean up this game instance and remove it from the registry
     */
    async cleanup() {
        await super.cleanup();
        // Remove this instance from the registry
        TwoPlayerMode.GAME_REGISTRY.delete(this.gameInstanceId);
        logger.info(`Two-Player game instance ${this.gameInstanceId} cleaned up`, this.loggingContext);
    }

    async getReplayData() {
        return {
            ...this.replayData,
            rounds: this.replayData.rounds.map(round => ({
                ...round,
                display: TableFormatter.formatRoundTable(round)[0]
            }))
        };
    }

    formatReplaySummary() {
        const metrics = this.replayData.metadata.twoPlayerSpecific.performanceMetrics;
        const avgGuesses = this.calculateAverageGuesses();
        const success = this.isSuccessful();
        
        return {
            totalRounds: TwoPlayerMode.TOTAL_ROUNDS,
            completedRounds: this.gameState.team.roundsCompleted,
            averageGuesses: avgGuesses.toFixed(1),
            success,
            threshold: this.winThreshold,
            perfectRounds: metrics.perfectRounds
        };
    }

    /**
     * Start a new round for the two-player game
     * @returns {Promise<Object>} The current round state
     */
    async startRound() {
        const startTime = Date.now();
        
        try {
            // Acquire mutex to ensure thread safety
            const release = await this.mutex.acquire();
            
            try {
                // Check if game is active
                if (this.gameState.status !== 'active') {
                    // Initialize the game if it's not active yet
                    await this.start({
                        players: this.players.map(id => ({ id })),
                        matchId: this.gameInstanceId
                    });
                } else {
                    // Start a new round
                    await this.startNewRound();
                }
                
                // Get the current round state for UI display
                const roundState = this.getCurrentRoundState();
                
                // Create embed to display to players
                const embed = new EmbedBuilder()
                    .setTitle(`Round ${roundState.roundNumber} of ${roundState.totalRounds}`)
                    .setDescription('Words have been selected! Send your guesses via DM to try to match with your teammate.')
                    .setColor(0x00ffff)
                    .addFields(
                        { name: 'Game ID', value: this.gameInstanceId, inline: true },
                        { name: 'Team', value: this.players.map(id => `<@${id}>`).join(' & '), inline: true },
                        { name: 'Words', value: '```\n' + roundState.display + '\n```', inline: false },
                        { name: 'Instructions', value: 'Send one-word guesses directly to the bot. Try to think of a word that will match with your teammate!', inline: false }
                    )
                    .setFooter({ text: `Game Instance: ${this.gameInstanceId}` });
                
                // Record performance metric
                performanceMonitor.recordOperation('two_player_start_round', Date.now() - startTime);
                
                return {
                    status: 'started',
                    roundNumber: roundState.roundNumber,
                    totalRounds: roundState.totalRounds,
                    channelMessage: { embeds: [embed] }
                };
            } finally {
                // Always release the mutex
                release();
            }
        } catch (error) {
            // Log error with context
            logger.error('Failed to start Two-Player round', {
                error,
                gameInstanceId: this.gameInstanceId,
                serverId: this.serverId,
                channelId: this.channelId,
                duration: Date.now() - startTime
            });
            
            throw createError('Failed to start round', error.code || ErrorCodes.UNKNOWN_ERROR, {
                originalError: error.message
            });
        }
    }
}

module.exports = TwoPlayerMode; 