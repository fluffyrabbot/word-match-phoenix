/**
 * Word manager for word validation and generation with variations support
 * @module WordManager
 */

/**
 * @typedef {Object} WordValidationOptions
 * @property {number} [minLength] - Minimum length required for the word
 * @property {boolean} [allowVariations] - Whether to allow word variations
 * @property {Set<string>} [excludeWords] - Set of words to exclude
 */

/**
 * @typedef {Object} WordStats
 * @property {number} totalAttempts - Total number of attempts using this word
 * @property {number} successfulAttempts - Number of successful attempts
 * @property {number} failedAttempts - Number of failed attempts
 * @property {Date} lastUsed - Last time the word was used
 */

/**
 * @typedef {Object} HealthStatus
 * @property {string} status - Current health status ('healthy'|'degraded'|'error')
 * @property {number} dictionarySize - Number of words in dictionary
 * @property {Object} metrics - Performance metrics
 * @property {number} metrics.avgValidationTime - Average time for word validation
 * @property {number} metrics.avgMatchTime - Average time for word matching
 * @property {Object} cache - Cache health information
 * @property {string} [error] - Error message if status is not healthy
 */

/**
 * @interface WordManagerInterface
 * @description Public API for word management operations
 */

const fs = require('fs').promises;
const path = require('path');
const logger = require('./logger');
const { createError, ErrorCodes } = require('./errorHandler');
const { lemmatizer } = require('lemmatizer');
const pluralize = require('pluralize');
const readline = require('readline');
const config = require('../config/defaults');
const { CacheManager } = require('./cacheManager');
const BaseComponent = require('./baseComponent');
const Mutex = require('./mutex');

/**
 * Standard error codes for WordManager operations
 * Centralizes all word-related error codes
 */
const WORD_ERROR_CODES = {
    VALIDATION: {
        INVALID_LENGTH: ErrorCodes.SYSTEM.VALIDATION,
        INVALID_CHARS: ErrorCodes.INVALID_INPUT,
        BLACKLISTED: ErrorCodes.USER.INVALID_INPUT,
        NOT_IN_DICTIONARY: ErrorCodes.USER.INVALID_INPUT,
        RATE_LIMIT: ErrorCodes.SYSTEM.LIMIT_EXCEEDED
    },
    GENERATION: {
        FAILED: ErrorCodes.SYSTEM.GENERAL,
        DICTIONARY_LOAD_FAILED: ErrorCodes.SYSTEM.IO_ERROR,
        NOT_IN_DICTIONARY: ErrorCodes.USER.INVALID_INPUT,
        INVALID_INPUT: ErrorCodes.INVALID_INPUT
    },
    CACHE: {
        MISS: ErrorCodes.SYSTEM.GENERAL
    }
};

class WordManager extends BaseComponent {
    /**
     * @static
     * @constant
     * @description Configuration constants for the WordManager
     */
    static CONSTANTS = {
        WORD: {
            REGEX: /^[a-z]+$/,
            MIN_LENGTH: 1,
            MAX_LENGTH: 45,
            GENERATION: {
                MIN_LENGTH: 3,
                MAX_LENGTH: 8
            }
        },
        CACHE: {
            DEFAULT_SIZE: 10000,
            TTL: {
                DICTIONARY: 3600,    // 1 hour
                VARIATIONS: 1800,    // 30 minutes
                FORMS: 900,         // 15 minutes
                VALIDATION: 300     // 5 minutes
            },
            METRICS: {
                VALIDATION_WINDOW: 1000,  // 1 second window for validation rate limiting
                MAX_VALIDATIONS: 100     // Maximum validations per window
            }
        },
        VARIATIONS: {
            DEFAULT: {
                'color': ['colour'],
                'center': ['centre'],
                'gray': ['grey'],
                'analyze': ['analyse'],
                'defense': ['defence']
            },
            PARTS_OF_SPEECH: ['verb', 'noun', 'adj']
        }
    };

    static DEFAULT_VARIATIONS = {
        'color': ['colour'],
        'center': ['centre'],
        'gray': ['grey'],
        'analyze': ['analyse'],
        'defense': ['defence']
    };

    static ERROR_CONTEXTS = {
        VALIDATION: 'word_validation',
        GENERATION: 'word_generation',
        DICTIONARY: 'dictionary_operation',
        CACHE: 'cache_operation'
    };

    static ERROR_DETAILS = {
        INVALID_LENGTH: 'Word length outside allowed range',
        INVALID_CHARS: 'Word contains invalid characters',
        BLACKLISTED: 'Word is in blacklist',
        NOT_IN_DICTIONARY: 'Word not found in dictionary',
        CACHE_MISS: 'Word not found in cache',
        GENERATION_FAILED: 'Failed to generate valid word',
        DICTIONARY_LOAD_FAILED: 'Failed to load dictionary',
        RATE_LIMIT: 'Validation rate limit exceeded'
    };

    /**
     * @static
     * @description Generates a cache key for word validation
     * @param {string} word - The word to generate a key for
     * @param {WordValidationOptions} options - Validation options
     * @returns {string} The generated cache key
     */
    static getCacheKey(word, options = {}) {
        return `v:${word}${options.minLength ? `:${options.minLength}` : ''}`;
    }

    /**
     * Creates a new WordManager instance
     * @param {string} [dictionaryPath] - Path to the dictionary file
     */
    constructor(dictionaryPath = path.join(__dirname, '../data/dictionary.txt')) {
        super({
            componentName: 'WordManager',
            metrics: {
                validationTime: [],
                matchTime: [],
                cacheHits: 0,
                cacheMisses: 0,
                validationRate: new Map()
            }
        });

        /** @private Dictionary state */
        this._state = {
            dictionary: new Set(),
            generationDictionary: new Set(),
            variations: new Map(),
            words: new Set(),
            usedWords: new Set(),
            stats: new Map()
        };

        /** @private File paths */
        this._paths = {
            dictionary: dictionaryPath,
            validation: './validdictionary.txt'
        };

        /** @private Cache configuration */
        this._cache = {
            validation: new Map(),
            size: WordManager.CONSTANTS.CACHE.DEFAULT_SIZE,
            manager: new CacheManager({
                namespace: 'words',
                ttl: WordManager.CONSTANTS.CACHE.TTL
            })
        };

        /** @private Runtime state */
        this._runtime = {
            isLoaded: false,
            isLoading: false,
            loadPromise: null,
            lastValidationReset: Date.now()
        };

        /** @private Mutex */
        this._mutex = new Mutex();

        // Initialize
        this.loadDictionary();
    }

    async initialize() {
        if (this.isInitialized) {
            return true;
        }

        try {
            await super.initialize();
            await this.loadDictionary();
            await this.loadVariations();
            
            await this.logEvent('word_manager.initialized', {
                dictionarySize: this._state.dictionary.size,
                variationsCount: this._state.variations.size
            });

            return true;
        } catch (error) {
            await this.logError(error, {
                context: 'initialization'
            });
            throw error;
        }
    }

    //#region Core Dictionary Operations
    /**
     * Loads and initializes the dictionary
     * @returns {Promise<boolean>} Whether the dictionary was loaded successfully
     * @throws {Error} If dictionary loading fails
     * @private
     */
    async loadDictionary() {
        // Use mutex to prevent concurrent dictionary loads
        await this._mutex.acquire('dictionary', 'wordManager');
        
        try {
            if (this._runtime.isLoading) {
                return this._runtime.loadPromise;
            }

            const startTime = Date.now();
            this._runtime.isLoading = true;
            this._runtime.loadPromise = (async () => {
                try {
                    const fileStream = fs.createReadStream(this._paths.dictionary);
                    const rl = readline.createInterface({
                        input: fileStream,
                        crlfDelay: Infinity
                    });

                    // Clear existing dictionary
                    this._state.dictionary.clear();
                    this._state.generationDictionary.clear();

                    for await (const line of rl) {
                        const word = line.trim().toLowerCase();
                        if (word && this.isValidGenerationWord(word)) {
                            this._state.dictionary.add(word);
                            
                            // Add to generation dictionary if it meets criteria
                            if (this.isValidGenerationWord(word)) {
                                this._state.generationDictionary.add(word);
                            }
                        }
                    }

                    this._runtime.isLoaded = true;
                    this._runtime.isLoading = false;

                    await this.logEvent('dictionary.loaded', {
                        size: this._state.dictionary.size,
                        generationSize: this._state.generationDictionary.size,
                        duration: Date.now() - startTime
                    });

                    return true;
                } catch (error) {
                    this._runtime.isLoaded = false;
                    this._runtime.isLoading = false;

                    await this.logError(error, {
                        context: 'dictionary_loading',
                        dictionaryPath: this._paths.dictionary,
                        duration: Date.now() - startTime
                    });
                    
                    throw error;
                }
            })();

            return this._runtime.loadPromise;
        } finally {
            await this._mutex.release('dictionary', 'wordManager');
        }
    }

    /**
     * Validates a word against the dictionary
     * @param {string} word - The word to validate
     * @param {WordValidationOptions} [options={}] - Validation options
     * @returns {Promise<boolean>} Whether the word is valid
     * @throws {Error} If word is invalid or dictionary not loaded
     * @public
     */
    async validateWord(word, options = {}) {
        await this.validateInitialized();
        const startTime = Date.now();

        try {
            await this._checkRateLimit();

            // Cache check
            const cacheKey = `validate:${word}`;
            const cached = await this._cache.manager.get(cacheKey);
            if (cached !== undefined) {
                this.metrics.cacheHits++;
                return cached;
            }
            this.metrics.cacheMisses++;

            // Basic validation
            if (!word || typeof word !== 'string') {
                throw createError(
                    WORD_ERROR_CODES.VALIDATION.INVALID_CHARS,
                    WordManager.ERROR_DETAILS.INVALID_CHARS,
                    { 
                        context: WordManager.ERROR_CONTEXTS.VALIDATION,
                        word 
                    }
                );
            }

            word = word.toLowerCase().trim();
            
            // Length check
            if (options.minLength && word.length < options.minLength) {
                throw createError(
                    WORD_ERROR_CODES.VALIDATION.INVALID_LENGTH,
                    WordManager.ERROR_DETAILS.INVALID_LENGTH,
                    { 
                        context: WordManager.ERROR_CONTEXTS.VALIDATION,
                        word, 
                        length: word.length, 
                        minRequired: options.minLength 
                    }
                );
            }

            // Dictionary check
            let isValid = this._state.dictionary.has(word);
            
            // Check variations if enabled
            if (!isValid && options.allowVariations) {
                isValid = await this._checkVariations(word);
            }

            // Cache result
            await this._cache.manager.set(
                cacheKey,
                isValid,
                WordManager.CONSTANTS.CACHE.TTL.VALIDATION
            );

            // Update metrics
            const duration = Date.now() - startTime;
            this.metrics.validationTime.push(duration);
            if (this.metrics.validationTime.length > 100) {
                this.metrics.validationTime.shift();
            }

            await this.logEvent('word.validated', {
                word,
                isValid,
                duration,
                cacheHit: false
            });

            return isValid;
        } catch (error) {
            await this.logError(error, {
                context: 'word_validation',
                word,
                duration: Date.now() - startTime
            });
            throw error;
        }
    }

    /**
     * Checks if a word exists in the dictionary
     * @param {string} word - The word to check
     * @returns {boolean} Whether the word exists
     * @public
     */
    hasWord(word) {
        if (!word || typeof word !== 'string') {
            return false;
        }
        return this._state.dictionary.has(word.toLowerCase());
    }

    /**
     * Gets the total number of words in the dictionary
     * @returns {number} Dictionary size
     * @public
     */
    getDictionarySize() {
        return this._state.dictionary.size;
    }
    //#endregion

    //#region Word Generation and Matching
    /**
     * Gets a random word from the dictionary
     * @param {Object} [options={}] - Options for word selection
     * @param {number} [options.minLength=1] - Minimum length of the word
     * @param {Set<string>} [options.excludeWords] - Set of words to exclude
     * @returns {Promise<string>} A random word meeting the criteria
     * @throws {Error} If no words match the criteria or dictionary not loaded
     * @public
     */
    async getRandomWord(options = {}) {
        if (!this._runtime.isLoaded) {
            await this.loadDictionary();
        }

        const { minLength = 1, excludeWords = new Set() } = options;
        
        const availableWords = [...this._state.dictionary].filter(word => 
            word.length >= minLength && !excludeWords.has(word)
        );

        if (availableWords.length === 0) {
            throw createError(
                WORD_ERROR_CODES.GENERATION.NOT_IN_DICTIONARY,
                WordManager.ERROR_DETAILS.NOT_IN_DICTIONARY,
                {
                    context: WordManager.ERROR_CONTEXTS.GENERATION,
                    minLength,
                    excludeWords: Array.from(excludeWords)
                }
            );
        }

        return availableWords[Math.floor(Math.random() * availableWords.length)];
    }

    /**
     * Gets multiple random words
     * @param {number} count - Number of words to get
     * @param {string[]} excludeWords - Words to exclude
     * @returns {Promise<string[]>} Array of random words
     * @throws {Error} If unable to generate requested words
     * @public
     */
    async getRandomWords(count = 2, excludeWords = []) {
        if (count < 1) {
            throw createError(
                WORD_ERROR_CODES.GENERATION.INVALID_INPUT,
                WordManager.ERROR_DETAILS.INVALID_INPUT,
                {
                    context: WordManager.ERROR_CONTEXTS.GENERATION,
                    requested: count,
                    minimum: 1
                }
            );
        }

        const words = new Set();
        const excluded = new Set(excludeWords);

        while (words.size < count) {
            try {
                const word = await this.getRandomWord(excluded);
                words.add(word);
                excluded.add(word);
            } catch (error) {
                throw createError(
                    WORD_ERROR_CODES.GENERATION.FAILED,
                    WordManager.ERROR_DETAILS.GENERATION_FAILED,
                    {
                        context: WordManager.ERROR_CONTEXTS.GENERATION,
                        requested: count,
                        generated: words.size,
                        originalError: error.message
                    }
                );
            }
        }

        return Array.from(words);
    }

    /**
     * Checks if two words match according to game rules
     * @param {string} word1 - First word to match
     * @param {string} word2 - Second word to match
     * @returns {Promise<boolean>} Whether the words match
     * @public
     */
    async matchWords(word1, word2) {
        // Early exit 1: Exact match check
        const norm1 = word1.toLowerCase();
        const norm2 = word2.toLowerCase();
        if (norm1 === norm2) return true;

        // Early exit 2: Cache check
        const cacheKey = `match:${norm1}:${norm2}`;
        const cached = await this._cache.manager.get(cacheKey);
        if (cached !== null) return cached;

        // Early exit 3: Dictionary presence
        if (!this._state.dictionary.has(norm1) || !this._state.dictionary.has(norm2)) {
            return false;
        }

        // Get variations efficiently
        const [variations1, variations2] = await Promise.all([
            this.getAllWordVariations(norm1),
            this.getAllWordVariations(norm2)
        ]);

        // Use Set intersection for efficiency
        const intersection = new Set([...variations1].filter(x => variations2.has(x)));
        const result = intersection.size > 0;

        // Cache result
        await this._cache.manager.set(cacheKey, result, WordManager.CONSTANTS.CACHE.TTL.VARIATIONS);
        return result;
    }
    //#endregion

    //#region Word Variations and Forms
    /**
     * Gets all forms of a word (singular, plural, base)
     * @param {string} word - Word to get forms for
     * @param {string[]} forms - Forms to generate
     * @returns {Object} Word forms
     * @private
     */
    getWordForms(word, forms = ['singular', 'plural', 'base']) {
        const result = {};
        try {
            if (forms.includes('singular')) result.singular = pluralize.singular(word);
            if (forms.includes('plural')) result.plural = pluralize.plural(word);
            if (forms.includes('base')) {
                const lemma = lemmatizer.lemmatize(word);
                if (lemma !== word) result.base = lemma;
            }
        } catch (err) {
            logger.debug(`Failed to get word forms for ${word}`);
        }
        return result;
    }

    /**
     * Gets all variations of a word including forms and lemmas
     * @param {string} word - Word to get variations for
     * @returns {Promise<string[]>} Array of variations
     * @private
     */
    async getAllWordVariations(word) {
        const variations = new Set();
        variations.add(word);

        // Add known variations
        const knownVars = this._state.variations.get(word) || [];
        knownVars.forEach(v => variations.add(v));

        // Add lemmatized forms
        const lemmas = this.getLemmatizedForms(word);
        lemmas.forEach(lemma => {
            variations.add(lemma);
            const lemmaVars = this._state.variations.get(lemma) || [];
            lemmaVars.forEach(v => variations.add(v));
        });

        // Add word forms
        const forms = this.getWordForms(word);
        forms.forEach(form => {
            variations.add(form);
            const formVars = this._state.variations.get(form) || [];
            formVars.forEach(v => variations.add(v));
        });

        return Array.from(variations);
    }

    /**
     * Gets known variations of a word
     * @param {string} word - Word to get variations for
     * @returns {Promise<Set<string>>} Set of variations
     * @public
     */
    async getWordVariations(word) {
        return this._state.variations.get(word) || new Set();
    }

    /**
     * Loads and initializes word variations
     * @returns {Promise<void>}
     * @private
     */
    async loadVariations() {
        const startTime = Date.now();
        try {
            // Load default variations
            for (const [word, variants] of Object.entries(WordManager.DEFAULT_VARIATIONS)) {
                this._state.variations.set(word, variants);
                for (const variant of variants) {
                    this._state.variations.set(variant, [word]);
                }
            }

            await this.logEvent('variations.loaded', {
                count: this._state.variations.size,
                duration: Date.now() - startTime
            });
        } catch (error) {
            await this.logError(error, {
                context: 'variations_loading',
                duration: Date.now() - startTime
            });
            throw error;
        }
    }

    /**
     * Gets lemmatized forms of a word
     * @param {string} word - Word to lemmatize
     * @returns {string[]} Lemmatized forms
     * @private
     */
    getLemmatizedForms(word) {
        const forms = new Set();
        
        // Try lemmatizing for different parts of speech
        ['verb', 'noun', 'adj'].forEach(pos => {
            try {
                const lemma = lemmatizer.lemmatize(word, pos);
                if (lemma !== word) {
                    forms.add(lemma);
                }
            } catch (err) {
                logger.debug(`Failed to lemmatize ${word} as ${pos}`);
            }
        });

        return Array.from(forms);
    }
    //#endregion

    //#region Statistics and Health
    /**
     * Gets statistics for a given word
     * @param {string} word - Word to get stats for
     * @returns {Promise<WordStats>} Word statistics
     * @public
     */
    async getWordStats(word) {
        const stats = this._state.stats.get(word) || {
            totalAttempts: 0,
            successfulAttempts: 0,
            failedAttempts: 0,
            lastUsed: null
        };
        return stats;
    }

    /**
     * Updates statistics for a word
     * @param {string} word - Word to update stats for
     * @param {Object} attempt - Attempt details
     * @param {boolean} success - Whether attempt was successful
     * @returns {Promise<WordStats>} Updated statistics
     * @private
     */
    async updateWordStats(word, attempt, success) {
        let stats = await this.getWordStats(word);
        stats = {
            ...stats,
            totalAttempts: stats.totalAttempts + 1,
            successfulAttempts: stats.successfulAttempts + (success ? 1 : 0),
            failedAttempts: stats.failedAttempts + (success ? 0 : 1),
            lastUsed: new Date()
        };
        this._state.stats.set(word, stats);
        return stats;
    }

    /**
     * Gets the health status of the WordManager
     * @returns {Promise<HealthStatus>} Health status object
     * @public
     */
    async getHealth() {
        try {
            const avgValidationTime = this.metrics.validationTime.length > 0
                ? this.metrics.validationTime.reduce((a, b) => a + b, 0) / this.metrics.validationTime.length
                : 0;

            return {
                status: this.isInitialized ? 'healthy' : 'initializing',
                dictionarySize: this._state.dictionary.size,
                metrics: {
                    avgValidationTime,
                    cacheHitRate: this.metrics.cacheHits / (this.metrics.cacheHits + this.metrics.cacheMisses),
                    validationRate: this.metrics.validationRate.size
                },
                cache: {
                    size: this._cache.validation.size,
                    maxSize: this._cache.size
                }
            };
        } catch (error) {
            await this.logError(error, {
                context: 'health_check'
            });
            return {
                status: 'error',
                error: error.message
            };
        }
    }
    //#endregion

    //#region Cache Management
    /**
     * Initializes the validation cache
     * @returns {Promise<void>}
     * @private
     */
    async initializeValidationCache() {
        try {
            // Check if validation dictionary exists
            await fs.access(this._paths.validation);
            
            // Preload most common words into cache
            const commonWords = new Set(this._state.generationDictionary); // Start with generation dictionary
            const stream = fs.createReadStream(this._paths.validation);
            const rl = readline.createInterface({ input: stream });
            
            let count = 0;
            for await (const line of rl) {
                const word = line.trim().toLowerCase();
                if (word && count < this._cache.size) {
                    this._cache.validation.set(word, true);
                    count++;
                }
            }
            
            logger.info(`Preloaded ${count} common words into validation cache`);
        } catch (error) {
            logger.warn('Validation dictionary not found, using generation dictionary for validation');
            // If validation dictionary doesn't exist, use generation dictionary
            this._paths.validation = null;
            this._cache.validation = new Map(
                Array.from(this._state.generationDictionary).map(word => [word, true])
            );
        }
    }

    /**
     * Validates a word against the dictionary without options
     * @param {string} word - Word to validate
     * @returns {boolean} Whether word is valid
     * @private
     */
    validateDictionaryWord(word) {
        if (!word || typeof word !== 'string') {
            return false;
        }
        return this._state.generationDictionary.has(word.toLowerCase().trim());
    }

    /**
     * Checks if a word is valid for generation
     * @param {string} word - Word to check
     * @returns {boolean} Whether word is valid for generation
     * @public
     */
    isValidGenerationWord(word) {
        if (!word || typeof word !== 'string') {
            return false;
        }
        return this._state.generationDictionary.has(word.toLowerCase());
    }

    async _checkVariations(word) {
        const variations = this._state.variations.get(word) || [];
        return variations.some(variant => this._state.dictionary.has(variant));
    }

    _checkValidationRate() {
        const now = Date.now();
        const window = now - WordManager.CONSTANTS.CACHE.METRICS.VALIDATION_WINDOW;
        
        // Clear old entries
        for (const [timestamp] of this.metrics.validationRate) {
            if (timestamp < window) {
                this.metrics.validationRate.delete(timestamp);
            }
        }

        // Check rate
        if (this.metrics.validationRate.size >= WordManager.CONSTANTS.CACHE.METRICS.MAX_VALIDATIONS) {
            throw createError(
                WORD_ERROR_CODES.VALIDATION.RATE_LIMIT,
                WordManager.ERROR_DETAILS.RATE_LIMIT,
                {
                    context: WordManager.ERROR_CONTEXTS.VALIDATION,
                    current: this.metrics.validationRate.size,
                    max: WordManager.CONSTANTS.CACHE.METRICS.MAX_VALIDATIONS,
                    resetIn: this._runtime.lastValidationReset + WordManager.CONSTANTS.CACHE.METRICS.VALIDATION_WINDOW - now
                }
            );
        }

        // Record new validation
        this.metrics.validationRate.set(now, true);
        return true;
    }
}

module.exports = WordManager; 