const logger = require('../utils/logger');
const { WordManager } = require('../utils/wordManager');
const { CacheManager } = require('../utils/cacheManager');
const path = require('path');
const fs = require('fs/promises');
const { createError, ErrorCodes } = require('../utils/errorHandler');
const { Mutex } = require('../utils/mutex');
const performanceMonitor = require('../utils/performanceMonitor');
const { EmbedBuilder } = require('discord.js');
const { RatingManager } = require('../rating/RatingManager');
const BaseComponent = require('../utils/baseComponent');
const { EVENT_TYPES, GameEvent } = require('../utils/eventRegistry');
const ModeStatsHelper = require('../utils/modeStatsHelper');

class BaseMode extends BaseComponent {
    static CACHE_TTL = {
        STATE: 3600,  // 1 hour
        REPLAY: 86400 // 24 hours
    };

    // Game mode identifiers
    static GAME_MODES = {
        KNOCKOUT: 'knockout',
        RACE: 'race',
        TWO_PLAYER: 'twoPlayer',
        GOLF_RACE: 'golfRace',
        LONGFORM: 'longform'
    };

    /**
     * Check if a mode matches a target mode, handling both string literals and constants
     * @param {string} mode - The mode to check
     * @param {string} targetMode - The target mode to compare against
     * @returns {boolean} - Whether the modes match
     */
    static isMode(mode, targetMode) {
        if (typeof mode !== 'string') return false;
        // Handle both string literals and constants
        return mode === targetMode || mode === this.GAME_MODES[targetMode] || 
               mode === Object.entries(this.GAME_MODES).find(([_, value]) => value === targetMode)?.[0];
    }

    /**
     * Convert a mode string to its constant form if possible
     * @param {string} mode - The mode to normalize
     * @returns {string} - The normalized mode
     */
    static normalizeMode(mode) {
        if (typeof mode !== 'string') return mode;
        // If it's already a constant key (e.g., 'LONGFORM'), return it
        if (Object.keys(this.GAME_MODES).includes(mode.toUpperCase())) {
            return mode.toUpperCase();
        }
        // If it's a value (e.g., 'longform'), find the key
        const entry = Object.entries(this.GAME_MODES).find(([_, value]) => value === mode);
        if (entry) return entry[0];
        // Otherwise, just return the original
        return mode;
    }

    static STATE_VALIDATION_SCHEMA = {
        required: ['matchId', 'mode', 'status', 'teams', 'rounds'],
        properties: {
            matchId: { type: 'string' },
            mode: { type: 'string', enum: Object.values(BaseMode.GAME_MODES) },
            status: { enum: ['pending', 'active', 'completed', 'error'] },
            teams: { type: 'object' },
            rounds: { type: 'array' }
        }
    };

    /**
     * Creates a new instance of BaseMode
     * @param {Object} options - Configuration options
     * @param {string} [options.serverId] - The server ID
     * @param {string} [options.channelId] - The channel ID
     * @param {string} [options.gameInstanceId] - Unique ID for this game instance (for parallel execution)
     */
    constructor(options = {}) {
        super(options);
        this.serverId = options.serverId;
        this.channelId = options.channelId;
        
        // Instance ID for parallel execution
        this.gameInstanceId = options.gameInstanceId || null;
        
        // Initialize caching with namespace
        this.cache = new CacheManager(this._getCacheNamespace(), {
            ttl: BaseMode.CACHE_TTL.STATE
        });
        
        // Add default logging context
        this.loggingContext = {
            serverId: this.serverId,
            channelId: this.channelId,
            mode: this.constructor.name,
            gameInstanceId: this.gameInstanceId
        };
        
        this.gameState = options.gameState || {
            status: 'pending',
            teams: new Map(),
            rounds: [],
            mode: BaseMode.GAME_MODES.KNOCKOUT // Default mode
        };
        
        // Initialize rating manager
        this.ratingManager = new RatingManager();
        
        // Initialize replay data structure
        this.replayData = {
            metadata: {
                mode: this.gameState.mode,
                startTime: Date.now(),
                serverId: this.serverId,
                channelId: this.channelId
            },
            rounds: []
        };
        
        this.maxCacheSize = options.maxCacheSize || 1000;
        this.batchSize = options.batchSize || 100;
        this.rateLimitWindow = options.rateLimitWindow || 60000;
        this.maxRequestsPerWindow = options.maxRequestsPerWindow || 100;
        this.redis = options.redis;
        
        // Initialize components
        this.cacheManager = new CacheManager({
            redis: this.redis,
            maxSize: this.maxCacheSize,
            namespace: 'game'
        });
        
        this.stateCache = new CacheManager('gameState', {
            maxSize: this.maxCacheSize,
            batchSize: this.batchSize,
            compressionThreshold: 1024
        });
        
        this.mutex = new Mutex({
            spinCount: options.spinCount || 2,
            fastPathThreshold: options.fastPathThreshold || 500,
            maxWaitTime: options.maxWaitTime || 5000
        });

        this.rateLimits = new Map();
        this.maxRetries = options.maxRetries || 3;
        this.backoffDelay = options.backoffDelay || 1000;

        this.healthStatus = {
            status: 'initializing',
            lastCheck: Date.now(),
            errors: [],
            warnings: []
        };

        // Initialize stats helper if game state is available
        this.initializeStatsHelper();
    }

    /**
     * Get the appropriate cache namespace based on whether this is a parallel instance
     * @private
     * @returns {string} - The cache namespace
     */
    _getCacheNamespace() {
        if (this.gameInstanceId) {
            // For parallel execution modes
            return `server:${this.serverId}:${this.constructor.name.toLowerCase()}:${this.gameInstanceId}`;
        }
        // For non-parallel modes
        return `server:${this.serverId}:${this.constructor.name.toLowerCase()}`;
    }

    /**
     * Initialize the mode
     * @param {Object} options - Initialization options
     * @returns {Promise<boolean>} - Whether initialization was successful
     */
    async initialize(options = {}) {
        if (this.isInitialized) return true;
        
        try {
            // Initialize base components
            this.wordManager = new WordManager();
            
            // Add event context
            this.eventContext = {
                serverId: this.serverId,
                channelId: this.channelId,
                mode: this.constructor.name,
                gameInstanceId: this.gameInstanceId
            };
            
            // Log initialization
            logger.info(`Initializing ${this.constructor.name} mode`, {
                ...this.loggingContext,
                options
            });
            
            this.isInitialized = true;
            return true;
        } catch (error) {
            logger.error(`Error initializing ${this.constructor.name} mode`, {
                error,
                ...this.loggingContext
            });
            return false;
        }
    }

    /**
     * Get a value from the cache using the game instance namespace
     * @param {string} key - The cache key
     * @returns {Promise<any>} - The cached value
     */
    async getCacheValue(key) {
        return this.cache.get(key);
    }

    /**
     * Set a value in the cache using the game instance namespace
     * @param {string} key - The cache key
     * @param {any} value - The value to cache
     * @param {number} [ttl] - Optional TTL override
     * @returns {Promise<void>}
     */
    async setCacheValue(key, value, ttl) {
        return this.cache.set(key, value, ttl || BaseMode.CACHE_TTL.STATE);
    }

    /**
     * Initializes the stats helper for tracking game statistics
     * Can be called during construction or after game state is fully initialized
     * @returns {ModeStatsHelper} The initialized stats helper
     */
    initializeStatsHelper() {
        try {
            // Only create a new instance if one doesn't already exist
            if (!this.statsHelper) {
                if (this.gameState) {
                    // Ensure the gameState has serverId to avoid issues
                    if (!this.gameState.serverId && this.serverId) {
                        this.gameState.serverId = this.serverId;
                    }
                    if (!this.gameState.channelId && this.channelId) {
                        this.gameState.channelId = this.channelId;
                    }
                    
                    this.statsHelper = new ModeStatsHelper(this.gameState);
                    logger.debug('Stats helper initialized', {
                        mode: this.gameState.mode,
                        matchId: this.gameState.matchId
                    });
                    return this.statsHelper;
                } else {
                    logger.warn('Cannot initialize stats helper: gameState not available');
                    return null;
                }
            }
            return this.statsHelper;
        } catch (error) {
            logger.error('Failed to initialize stats helper', { error });
            return null;
        }
    }
    
    /**
     * Gets the stats helper, initializing it if necessary
     * @returns {ModeStatsHelper} The stats helper instance
     */
    getStatsHelper() {
        return this.statsHelper || this.initializeStatsHelper();
    }

    async logModeEvent(event, data = {}) {
        if (!(event in EVENT_TYPES.MODE)) {
            throw createError('Invalid event type', ErrorCodes.INVALID_EVENT_TYPE, {
                event,
                validEvents: Object.keys(EVENT_TYPES.MODE)
            });
        }

        await this.logEvent(new GameEvent(event, {
            mode: this.gameState.mode,
            serverId: this.serverId,
            channelId: this.channelId,
            matchId: this.gameState.matchId,
            status: this.gameState.status,
            ...data
        }));
    }

    async logModeError(error, context = {}) {
        await this.logEvent(new GameEvent(EVENT_TYPES.MODE.ERROR, {
            mode: this.gameState.mode,
            serverId: this.serverId,
            channelId: this.channelId,
            matchId: this.gameState.matchId,
            status: this.gameState.status,
            error: {
                message: error.message,
                code: error.code,
                stack: error.stack
            },
            ...context
        }));
    }

    async validateState(state) {
        const startTime = Date.now();
        try {
            if (!state) {
                throw createError('Invalid game state: state is null or undefined', ErrorCodes.INVALID_STATE);
            }

            // Check required fields
            for (const field of BaseMode.STATE_VALIDATION_SCHEMA.required) {
                if (!(field in state)) {
                    throw createError(`Invalid game state: missing required field '${field}'`, ErrorCodes.INVALID_STATE);
                }
            }

            // Validate field types and values
            const { properties } = BaseMode.STATE_VALIDATION_SCHEMA;
            for (const [field, schema] of Object.entries(properties)) {
                if (field in state) {
                    if (schema.type && typeof state[field] !== schema.type) {
                        throw createError(`Invalid game state: field '${field}' has wrong type`, ErrorCodes.INVALID_STATE);
                    }
                    if (schema.enum && !schema.enum.includes(state[field])) {
                        throw createError(`Invalid game state: field '${field}' has invalid value`, ErrorCodes.INVALID_STATE);
                    }
                }
            }

            await this.logModeEvent(EVENT_TYPES.MODE.STATE_VALIDATED, {
                duration: Date.now() - startTime,
                metadata: {
                    stateFields: Object.keys(state),
                    validationSchema: Object.keys(properties)
                }
            });

            return true;
        } catch (error) {
            await this.logModeError(error, {
                context: 'state_validation',
                duration: Date.now() - startTime,
                metadata: {
                    stateFields: state ? Object.keys(state) : null
                }
            });
            throw error;
        }
    }

    async validateGuess(guess, context = {}) {
        const startTime = Date.now();
        try {
            // Check rate limit first (fast path)
            const userId = context.userId;
            if (userId && !await this.checkRateLimit(userId)) {
                throw createError('Rate limit exceeded', ErrorCodes.RATE_LIMIT);
            }

            // Validate word format (fast path)
            if (!guess || typeof guess !== 'string' || !/^[a-zA-Z]+$/.test(guess)) {
                await this.logModeEvent('guess_invalid_format', {
                    userId,
                    duration: Date.now() - startTime,
                    metadata: { guess }
                });
                return { valid: false, reason: 'Invalid word format' };
            }

            // Check word validity
            const isValid = await this.wordManager.validateWord(guess, context);
            
            // Update rate limit only for valid attempts
            if (isValid && userId) {
                await this.updateRateLimit(userId);
            }

            await this.logModeEvent('guess_validated', {
                userId,
                duration: Date.now() - startTime,
                metadata: {
                    isValid,
                    guess: guess.toLowerCase(),
                    context: { ...context, userId }
                }
            });

            return { valid: isValid, word: guess.toLowerCase() };
        } catch (error) {
            await this.logModeError(error, {
                context: 'guess_validation',
                userId: context.userId,
                duration: Date.now() - startTime,
                metadata: { guess }
            });
            throw error;
        }
    }

    async checkRateLimit(userId) {
        const now = Date.now();
        const userRateLimit = this.rateLimits.get(userId);
        
        if (!userRateLimit) return true;
        
        // Clean up old timestamps
        while (userRateLimit.length > 0 && userRateLimit[0] < now - this.rateLimitWindow) {
            userRateLimit.shift();
        }
        
        return userRateLimit.length < this.maxRequestsPerWindow;
    }

    async updateRateLimit(userId) {
        const now = Date.now();
        
        if (!this.rateLimits.has(userId)) {
            this.rateLimits.set(userId, []);
        }
        
        const userRateLimit = this.rateLimits.get(userId);
        userRateLimit.push(now);
        
        // Clean up old timestamps
        while (userRateLimit.length > 0 && userRateLimit[0] < now - this.rateLimitWindow) {
            userRateLimit.shift();
        }
    }

    async getState(gameId) {
        return this.stateCache.get(`game:${gameId}`);
    }

    async setState(gameId, state, ttl = 3600000) {
        await this.stateCache.set(`game:${gameId}`, state, ttl);
    }

    async updateState(gameId, updateFn) {
        return this.mutex.runExclusive(async () => {
            const state = await this.getState(gameId);
            if (!state) {
                throw createError(
                    'Game state not found',
                    ErrorCodes.INVALID_STATE,
                    { gameId }
                );
            }
            
            const updatedState = await updateFn(state);
            await this.setState(gameId, updatedState);
            return updatedState;
        }, 1000);
    }

    async batchProcessGuesses(guesses, context = {}) {
        const results = new Map();
        
        for (let i = 0; i < guesses.length; i += this.batchSize) {
            const batch = guesses.slice(i, i + this.batchSize);
            const validations = await Promise.all(
                batch.map(guess => this.validateGuess(guess, context))
            );
            
            validations.forEach((validation, index) => {
                results.set(batch[index], validation);
            });
            
            // Small delay between batches to prevent resource exhaustion
            if (i + this.batchSize < guesses.length) {
                await new Promise(resolve => setImmediate(resolve));
            }
        }
        
        return results;
    }

    async cleanup() {
        // Clear rate limits older than window
        const now = Date.now();
        for (const [userId, timestamps] of this.rateLimits) {
            while (timestamps.length > 0 && timestamps[0] < now - this.rateLimitWindow) {
                timestamps.shift();
            }
            if (timestamps.length === 0) {
                this.rateLimits.delete(userId);
            }
        }
    }

    getRateLimitConfig() {
        return this.rateLimits[this.gameState.mode] || this.rateLimits.default;
    }

    getSupportedFeatures() {
        return {
            timeLimit: !!this.timeLimit,
            rateLimit: true,
            invalidGuesses: true,
            caching: true,
            wordVariations: true,
            replaySupport: true,
            guessValidation: true,
            serverIsolation: true
        };
    }

    backupState() {
        // Backup using a deep clone. Ensure gameState is fully serializable.
        this.stateBackup = JSON.parse(JSON.stringify(this.gameState));
        this.lastValidState = Date.now();
    }

    restoreState() {
        if (this.stateBackup && this.lastValidState) {
            const age = Date.now() - this.lastValidState;
            if (age < BaseMode.CACHE_TTL.STATE * 1000) {
                Object.assign(this.gameState, this.stateBackup);
                return true;
            }
        }
        return false;
    }

    async getRandomWordsWithRateLimit(count = 2) {
        const key = `word_gen:${this.gameState.matchId}`;
        const now = Date.now();
        
        // Use atomic operation to check and update rate limit
        return await this.cacheManager.atomicUpdate(
            'rateLimit',
            key,
            async lastRequest => {
                lastRequest = lastRequest || 0;
                const rateLimit = this.rateLimits[this.gameState.mode] || this.rateLimits.default;
                
                if (now - lastRequest < rateLimit) {
                    throw createError(
                        'Too many word generation requests',
                        ErrorCodes.RATE_LIMIT_EXCEEDED,
                        { waitTime: rateLimit - (now - lastRequest) }
                    );
                }
                
                // Use cache for word generation
                const cacheKey = `random_words:${count}:${now}`;
                const cached = await this.cacheManager.get('wordCache', cacheKey);
                if (cached) {
                    return cached;
                }

                const words = await this.wordManager.getRandomWords(count);
                await this.cacheManager.set('wordCache', cacheKey, words, BaseMode.CACHE_TTL.WORD_CACHE);
                return words;
            },
            BaseMode.CACHE_TTL.RATE_LIMIT
        );
    }

    async processGuess(teamId, playerId, guess) {
        const startTime = Date.now();
        try {
            const validationResult = await this.validateGuess(guess, { teamId, playerId });
            
            if (!validationResult.valid) {
                await this.logModeEvent('guess_rejected', {
                    teamId,
                    playerId,
                    duration: Date.now() - startTime,
                    metadata: {
                        guess,
                        reason: validationResult.reason
                    }
                });
                return { valid: false, reason: validationResult.reason };
            }

            const result = await this.handleValidGuess(teamId, playerId, validationResult.word);
            await this.logModeEvent('guess_processed', {
                teamId,
                playerId,
                duration: Date.now() - startTime,
                metadata: {
                    guess: validationResult.word,
                    result
                }
            });

            return result;
        } catch (error) {
            await this.logModeError(error, {
                context: 'process_guess',
                teamId,
                playerId,
                duration: Date.now() - startTime,
                metadata: { guess }
            });
            throw error;
        }
    }

    async saveState() {
        const startTime = Date.now();
        try {
            const state = {
                ...this.gameState,
                teams: Array.from(this.gameState.teams.entries()),
                scores: Array.from(this.gameState.scores.entries())
            };

            await this.validateState(state);
            await this.stateCache.set(
                `game:${this.serverId}:${this.gameState.matchId}`,
                state,
                BaseMode.CACHE_TTL.STATE
            );

            await this.logModeEvent('state_saved', {
                duration: Date.now() - startTime,
                metadata: {
                    stateSize: JSON.stringify(state).length,
                    teams: state.teams.length,
                    rounds: state.rounds.length
                }
            });

            return true;
        } catch (error) {
            await this.logModeError(error, {
                context: 'save_state',
                duration: Date.now() - startTime
            });
            throw error;
        }
    }

    async loadState(matchId) {
        const startTime = Date.now();
        try {
            const state = await this.stateCache.get(`game:${this.serverId}:${matchId}`);
            
            if (!state) {
                throw createError('Game state not found', ErrorCodes.NOT_FOUND);
            }

            await this.validateState(state);
            
            // Convert arrays back to Maps
            this.gameState = {
                ...state,
                teams: new Map(state.teams),
                scores: new Map(state.scores)
            };

            await this.logModeEvent('state_loaded', {
                duration: Date.now() - startTime,
                metadata: {
                    matchId,
                    stateSize: JSON.stringify(state).length,
                    teams: state.teams.length,
                    rounds: state.rounds.length
                }
            });

            return this.gameState;
        } catch (error) {
            await this.logModeError(error, {
                context: 'load_state',
                matchId,
                duration: Date.now() - startTime
            });
            throw error;
        }
    }

    async saveReplay() {
        const startTime = Date.now();
        try {
            const replayPath = this.getServerPath('replays');
            await fs.mkdir(replayPath, { recursive: true });

            const replayData = {
                ...this.replayData,
                endTime: Date.now(),
                duration: Date.now() - this.replayData.metadata.startTime,
                finalState: this.gameState
            };

            const filePath = path.join(replayPath, `${this.gameState.matchId}.json`);
            await fs.writeFile(filePath, JSON.stringify(replayData, null, 2));

            await this.logModeEvent('replay_saved', {
                duration: Date.now() - startTime,
                metadata: {
                    matchId: this.gameState.matchId,
                    replaySize: JSON.stringify(replayData).length,
                    rounds: replayData.rounds.length,
                    gameDuration: replayData.duration
                }
            });

            return true;
        } catch (error) {
            await this.logModeError(error, {
                context: 'save_replay',
                duration: Date.now() - startTime
            });
            throw error;
        }
    }

    async updateRatings(gameResults) {
        const startTime = Date.now();
        try {
            const updates = await this.ratingManager.updateRatings(
                this.gameState.matchId,
                gameResults,
                this.gameState.mode
            );

            await this.logModeEvent('ratings_updated', {
                duration: Date.now() - startTime,
                metadata: {
                    matchId: this.gameState.matchId,
                    playerCount: Object.keys(gameResults).length,
                    ratingChanges: updates
                }
            });

            return updates;
        } catch (error) {
            await this.logModeError(error, {
                context: 'update_ratings',
                duration: Date.now() - startTime,
                metadata: {
                    matchId: this.gameState.matchId,
                    gameResults
                }
            });
            throw error;
        }
    }

    /**
     * Base implementation of endGame that saves stats
     * @param {string} reason - The reason for ending the game
     * @returns {Promise<Object>} The game results
     */
    async endGame(reason = 'complete') {
        const startTime = Date.now();
        try {
            // Update game state
            this.gameState.status = 'completed';
            this.gameState.endTime = Date.now();
            this.gameState.endReason = reason;

            // Calculate final scores and update ratings
            const finalScores = this.gameState.scores instanceof Map ? 
                Array.from(this.gameState.scores.entries()) : 
                (Array.isArray(this.gameState.scores) ? this.gameState.scores : []);
            
            const gameResults = Object.fromEntries(finalScores);
            const gameDuration = this.gameState.endTime - (this.gameState.startTime || startTime);
            
            // Determine winner based on scores
            const winner = this.determineWinner();

            // Save final state and replay
            try {
                await this.saveState();
            } catch (saveStateError) {
                logger.error('Failed to save final game state', { 
                    error: saveStateError,
                    matchId: this.gameState.matchId
                });
            }
            
            try {
                await this.saveReplay();
            } catch (saveReplayError) {
                logger.error('Failed to save game replay', { 
                    error: saveReplayError,
                    matchId: this.gameState.matchId
                });
            }

            // Update ratings if available
            try {
                if (Object.keys(gameResults).length > 0) {
                    await this.updateRatings(gameResults);
                }
            } catch (ratingsError) {
                logger.error('Failed to update ratings', { 
                    error: ratingsError,
                    matchId: this.gameState.matchId 
                });
            }
            
            // Get team data in a safe way regardless of how it's stored
            let teamResults = [];
            try {
                if (this.gameState.teams instanceof Map) {
                    teamResults = Array.from(this.gameState.teams.values());
                } else if (this.gameState.teams instanceof Set) {
                    teamResults = Array.from(this.gameState.teams);
                } else if (Array.isArray(this.gameState.teams)) {
                    teamResults = this.gameState.teams;
                } else if (this.gameState.activeTeams instanceof Map) {
                    teamResults = Array.from(this.gameState.activeTeams.values());
                } else if (this.gameState.activeTeams instanceof Set) {
                    teamResults = Array.from(this.gameState.activeTeams);
                } else if (Array.isArray(this.gameState.activeTeams)) {
                    teamResults = this.gameState.activeTeams;
                }
            } catch (teamError) {
                logger.error('Error extracting team results', { 
                    error: teamError,
                    matchId: this.gameState.matchId
                });
            }
            
            // Save match stats if stats helper is available
            try {
                const statsHelper = this.getStatsHelper();
                if (statsHelper) {
                    await statsHelper.saveMatchStats({
                        winner: winner?.id || winner?.teamId || winner,
                        scores: finalScores,
                        gameDuration,
                        teamResults
                    });
                }
            } catch (statsError) {
                logger.error('Failed to save match stats', { 
                    error: statsError,
                    matchId: this.gameState.matchId
                });
            }
            
            // Log generic game end event
            await this.logModeEvent(EVENT_TYPES.GAME.ENDED, {
                duration: Date.now() - startTime,
                metadata: {
                    winner: winner?.id || winner?.teamId || winner,
                    reason,
                    gameDuration,
                    finalScores
                }
            });
            
            return {
                winner,
                reason,
                scores: gameResults
            };
        } catch (error) {
            await this.logModeError(error, {
                context: 'end_game',
                duration: Date.now() - startTime,
                metadata: {
                    reason
                }
            });
            throw error;
        }
    }

    /**
     * Utility method to determine the winner based on scores
     * @returns {any} The winner (player ID, team ID, or team object)
     */
    determineWinner() {
        if (!this.gameState.scores || 
            (!(this.gameState.scores instanceof Map) && !Array.isArray(this.gameState.scores))) {
            return null;
        }
        
        let scores = [];
        if (this.gameState.scores instanceof Map) {
            scores = Array.from(this.gameState.scores.entries());
        } else {
            scores = this.gameState.scores;
        }
        
        if (scores.length === 0) return null;
        
        // Sort scores in descending order
        const sortedScores = [...scores].sort((a, b) => {
            const scoreA = typeof a[1] === 'number' ? a[1] : 0;
            const scoreB = typeof b[1] === 'number' ? b[1] : 0;
            return scoreB - scoreA;
        });
        
        // Get the highest score
        const highestScore = sortedScores[0][1];
        
        // Check if there's a tie for first place
        const winnersCount = sortedScores.filter(([_, score]) => score === highestScore).length;
        
        if (winnersCount === 1) {
            // Clear winner - return ID
            return sortedScores[0][0];
        }
        
        // It's a tie - no single winner
        return null;
    }

    getServerPath(subPath) {
        return path.join(__dirname, '../data/servers', this.serverId, subPath);
    }

    // Helper methods for game modes
    isValidTeamSize(size) {
        return size >= this.minTeamSize && size <= this.maxTeamSize;
    }

    getTeamScore(team) {
        return {
            id: team.id,
            name: team.name,
            score: team.score || 0,
            members: team.members,
            active: team.active !== false
        };
    }

    formatTime(ms) {
        return (ms / 1000).toFixed(1);
    }

    async handleError(error, teamId) {
        logger.error('Game mode error:', error);
        await this.backupState();
        
        // Notify affected players
        const team = await this.getTeam(teamId);
        if (team) {
            const embed = new EmbedBuilder()
                .setTitle('❌ Error')
                .setDescription('An error occurred processing your guess. Please try again.')
                .setColor(0xff0000)
                .setTimestamp();
            
            await Promise.all(team.members.map(async pid => {
                const player = await this.client.users.fetch(pid);
                if (player) {
                    await player.send({ embeds: [embed] });
                }
            }));
        }

        // Record error in performance monitor
        performanceMonitor.recordStateError();
    }

    /**
     * Retrieves and formats team stats for display
     * @param {string} teamId - The team ID to get stats for
     * @returns {Promise<Object>} The formatted team stats
     */
    async getTeamStats(teamId) {
        try {
            // Ensure statsHelper is initialized
            if (!this.statsHelper) {
                this.initializeStatsHelper();
            }
            
            // Get stats and trends for the team
            const [stats, trends] = await Promise.all([
                this.statsHelper.getTeamStats(teamId),
                this.statsHelper.getTeamTrends(teamId)
            ]);
            
            // Format for display
            const formattedStats = {
                totalGames: stats.totalGames || 0,
                wins: stats.wins || 0,
                losses: stats.losses || 0,
                winRate: stats.totalGames > 0 ? Math.round((stats.wins / stats.totalGames) * 100) : 0,
                trend: trends.winRateTrend > 0 ? '📈' : (trends.winRateTrend < 0 ? '📉' : '➡️'),
                recentWinRate: Math.round(trends.recentWinRate * 100)
            };
            
            return formattedStats;
        } catch (error) {
            logger.error('Failed to get team stats', {
                error,
                teamId,
                mode: this.gameState?.mode
            });
            
            // Return default values
            return {
                totalGames: 0,
                wins: 0,
                losses: 0,
                winRate: 0,
                trend: '➡️',
                recentWinRate: 0
            };
        }
    }

    /**
     * Tests the stats helper standardization with a variety of team formats
     * This method can be called from any game mode to verify standardization works
     * @returns {Promise<Object>} Standardization test results
     */
    async testStatsHelperStandardization() {
        try {
            // Ensure stats helper is initialized
            if (!this.statsHelper) {
                this.initializeStatsHelper();
            }
            
            if (!this.statsHelper) {
                throw new Error('Failed to initialize stats helper for testing');
            }
            
            const testResults = {
                standardizedResults: [],
                errors: []
            };
            
            // Create test teams with various formats
            const testTeams = [
                // Format 1: Map-style team
                {
                    id: 'test_team_1',
                    name: 'Test Team 1',
                    members: ['player1', 'player2'],
                    score: 10,
                    rounds: [
                        { matched: true, startTime: Date.now() - 5000, endTime: Date.now() },
                        { matched: false }
                    ]
                },
                // Format 2: Player as "team"
                {
                    id: 'player3',
                    name: 'Player Three',
                    score: 5
                },
                // Format 3: Team with guesses but no rounds
                {
                    id: 'test_team_2',
                    members: ['player4', 'player5'],
                    guesses: [{ word: 'test' }, { word: 'match' }],
                    guessCount: 10,
                    score: 3
                },
                // Format 4: Minimal team
                {
                    id: 'test_team_3'
                },
                // Format 5: Team with alternate property names
                {
                    teamId: 'test_team_4',
                    teamName: 'Alternate Format',
                    players: ['player6', 'player7'],
                    status: 'eliminated',
                    teamScore: 7
                }
            ];
            
            // Test standardization for each team
            for (const team of testTeams) {
                try {
                    const standardized = this.statsHelper.standardizeTeamData(team);
                    testResults.standardizedResults.push({
                        original: team,
                        standardized
                    });
                } catch (error) {
                    testResults.errors.push({
                        team,
                        error: error.message
                    });
                    logger.error('Error in standardization test', { 
                        error, 
                        team 
                    });
                }
            }
            
            logger.info('Stats helper standardization test completed', {
                successCount: testResults.standardizedResults.length,
                errorCount: testResults.errors.length
            });
            
            return testResults;
        } catch (error) {
            logger.error('Failed to run standardization test', { error });
            throw error;
        }
    }
}

module.exports = BaseMode; 