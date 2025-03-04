# Word Manager

## Table of Contents
1. [Overview](#overview)
2. [Architectural Design](#architectural-design)
3. [Class Details](#class-details)
   - [Constants](#constants)
   - [Constructor](#constructor)
   - [Methods](#methods)
4. [Dependencies](#dependencies)
5. [Performance Considerations](#performance-considerations)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Usage](#advanced-usage)

## Overview
The `WordManager` module provides word validation, generation, and management functionality for the Word Match Bot system. It serves as the central repository for all word-related operations, including dictionary lookups, word variation handling, word statistics tracking, and performance monitoring for word operations. It verifies that player-submitted words are valid according to game rules and generates valid words for game rounds.

## Architectural Design
The `WordManager` follows these design principles:

- **Dictionary-Based Validation**: Uses dictionary files for word validation
- **Variation Recognition**: Supports regional spelling variations (e.g., color/colour)
- **Lemmatization Support**: Identifies word forms across different parts of speech
- **Multi-Level Caching**: Implements caching for high-performance word operations
- **Rate Limiting**: Controls validation frequency to prevent abuse
- **Statistics Tracking**: Monitors word usage and success rates
- **Performance Metrics**: Tracks operation durations for system health monitoring
- **Extended BaseComponent**: Inherits from BaseComponent for standardized behavior

## Class Details

### Constants

#### `WordManager.CONSTANTS`
Configuration constants for the WordManager:

- **WORD**: Contains regex patterns and length constraints
  - `REGEX`: Regular expression for valid word characters (`/^[a-z]+$/`)
  - `MIN_LENGTH`: Minimum word length (1)
  - `MAX_LENGTH`: Maximum word length (45)
  - `GENERATION`: Settings for word generation
    - `MIN_LENGTH`: Minimum length for generated words (3)
    - `MAX_LENGTH`: Maximum length for generated words (8)

- **CACHE**: Cache configuration values
  - `DEFAULT_SIZE`: Default cache size (10000)
  - `TTL`: Time-to-live settings for different cache types
    - `DICTIONARY`: Dictionary cache TTL (3600s/1hr)
    - `VARIATIONS`: Variations cache TTL (1800s/30min)
    - `FORMS`: Word forms cache TTL (900s/15min)
    - `VALIDATION`: Validation cache TTL (300s/5min)
  - `METRICS`: Performance metrics settings
    - `VALIDATION_WINDOW`: Window for validation rate limiting (1000ms)
    - `MAX_VALIDATIONS`: Maximum validations per window (100)

- **VARIATIONS**: Word variation settings
  - `DEFAULT`: Default mapping of variations
  - `PARTS_OF_SPEECH`: Supported parts of speech for lemmatization

#### `WordManager.ERROR_CONTEXTS`
Error context identifiers:
- `VALIDATION`: For word validation errors
- `GENERATION`: For word generation errors
- `DICTIONARY`: For dictionary operation errors
- `CACHE`: For cache operation errors

#### `WordManager.ERROR_DETAILS`
Error detail message templates:
- `INVALID_LENGTH`: "Word length outside allowed range"
- `INVALID_CHARS`: "Word contains invalid characters"
- `BLACKLISTED`: "Word is in blacklist"
- `NOT_IN_DICTIONARY`: "Word not found in dictionary"
- `CACHE_MISS`: "Word not found in cache"
- `GENERATION_FAILED`: "Failed to generate valid word"
- `DICTIONARY_LOAD_FAILED`: "Failed to load dictionary"
- `RATE_LIMIT`: "Validation rate limit exceeded"

### Constructor
```javascript
constructor(dictionaryPath = path.join(__dirname, '../data/dictionary.txt'))
```
Creates a new WordManager instance.

**Parameters:**
- `dictionaryPath` (string, optional): Path to the dictionary file, defaults to '../data/dictionary.txt'

### Methods

#### `async initialize()`
Initializes the WordManager, loading the dictionary and variations.

**Returns:**
- Promise\<boolean\>: True if initialization was successful

**Throws:**
- Error if initialization fails

#### `async loadDictionary()`
Loads the dictionary from disk.

**Returns:**
- Promise\<boolean\>: True if dictionary was loaded successfully

**Throws:**
- Error if dictionary loading fails

#### `async validateWord(word, options = {})`
Validates a word against the dictionary.

**Parameters:**
- `word` (string): The word to validate
- `options` (Object): Validation options
  - `minLength` (number): Minimum length required
  - `allowVariations` (boolean): Whether to allow word variations
  - `excludeWords` (Set\<string\>): Words to exclude

**Returns:**
- Promise\<boolean\>: Whether the word is valid

**Throws:**
- Error if word is invalid or dictionary not loaded

#### `hasWord(word)`
Checks if a word exists in the dictionary.

**Parameters:**
- `word` (string): The word to check

**Returns:**
- boolean: Whether the word exists

#### `getDictionarySize()`
Gets the total number of words in the dictionary.

**Returns:**
- number: Dictionary size

#### `async getRandomWord(options = {})`
Gets a random word from the dictionary.

**Parameters:**
- `options` (Object): Options for word selection
  - `minLength` (number): Minimum length of the word (default: 1)
  - `excludeWords` (Set\<string\>): Set of words to exclude

**Returns:**
- Promise\<string\>: A random word meeting the criteria

**Throws:**
- Error if no words match the criteria or dictionary not loaded

#### `async getRandomWords(count = 2, excludeWords = [])`
Gets multiple random words.

**Parameters:**
- `count` (number): Number of words to get
- `excludeWords` (string[]): Words to exclude

**Returns:**
- Promise\<string[]\>: Array of random words

**Throws:**
- Error if unable to generate requested words

#### `async matchWords(word1, word2)`
Checks if two words match according to game rules.

**Parameters:**
- `word1` (string): First word to match
- `word2` (string): Second word to match

**Returns:**
- Promise\<boolean\>: Whether the words match

#### `async isWordUsed(word)`
Checks if a word has been used recently.

**Parameters:**
- `word` (string): Word to check

**Returns:**
- Promise\<boolean\>: Whether the word has been used

#### `async markWordUsed(word)`
Marks a word as used.

**Parameters:**
- `word` (string): Word to mark

**Returns:**
- Promise\<void\>

#### `async getAllWordVariations(word)`
Asynchronously retrieves all variations of a word.

**Parameters:**
- `word` (string): Base word

**Returns:**
- Promise\<string[]\>: Array of word variations

#### `async getWordVariations(word)`
Asynchronously gets known variations of a word.

**Parameters:**
- `word` (string): Base word

**Returns:**
- Promise\<string[]\>: Array of word variations

#### `async loadVariations()`
Asynchronously loads and initializes word variations.

**Returns:**
- Promise\<boolean\>: Whether variations loaded successfully

#### `getLemmatizedForms(word)`
Retrieves lemmatized forms of a word for different parts of speech.

**Parameters:**
- `word` (string): Word to process

**Returns:**
- string[]: Array of lemmatized forms

#### `async getWordStats(word)`
Asynchronously retrieves statistics for a given word.

**Parameters:**
- `word` (string): Word to get stats for

**Returns:**
- Promise\<Object\>: Word statistics

#### `async updateWordStats(word, { attempt = true, success = false })`
Asynchronously updates statistics for a word.

**Parameters:**
- `word` (string): Word to update
- `options` (Object): Update options
  - `attempt` (boolean): Whether an attempt was made
  - `success` (boolean): Whether the attempt was successful

**Returns:**
- Promise\<Object\>: Updated word statistics

#### `async getHealth()`
Asynchronously checks the health status of the WordManager.

**Returns:**
- Promise\<Object\>: Health status information

#### `async initializeValidationCache()`
Asynchronously initializes the validation cache.

**Returns:**
- Promise\<boolean\>: Whether initialization was successful

#### `validateDictionaryWord(word)`
Validates a word against the dictionary without options.

**Parameters:**
- `word` (string): Word to validate

**Returns:**
- boolean: Whether the word is valid

#### `isValidGenerationWord(word)`
Checks if a word is valid for generation.

**Parameters:**
- `word` (string): Word to check

**Returns:**
- boolean: Whether the word is valid for generation

#### `_checkRateLimit()`
Internal method to check validation rate limits.

**Returns:**
- Promise\<boolean\>: Whether operation is within rate limits

**Throws:**
- Error if rate limit exceeded

#### `_createError(message, context, details = {})`
Internal method to create standardized errors.

**Parameters:**
- `message` (string): Error message
- `context` (string): Error context
- `details` (Object): Additional error details

**Returns:**
- Error: Formatted error object

## Dependencies
- `fs.promises`: File system operations
- `path`: Path handling
- `logger`: Logging functionality
- `errorHandler`: Error handling utilities
- `lemmatizer`: Word lemmatization
- `pluralize`: Singular/plural conversion
- `readline`: For reading dictionary files line by line
- `config/defaults`: Configuration settings
- `cacheManager`: Cache management
- `baseComponent`: Base component class

## Performance Considerations
- **Dictionary Loading**: Initial dictionary loading can be slow for large files
- **Cache Management**: Proper TTL settings crucial for balancing memory and performance
- **Word Variations**: Handling variations adds overhead to validation
- **Lemmatization**: Word form detection adds computational complexity
- **Rate Limiting**: Prevents abuse but may impact legitimate high-frequency operations
- **Memory Usage**: Dictionary and cache size directly impact memory footprint
- **Validation Time**: Metrics should be monitored to identify performance regressions

## Troubleshooting
- **Dictionary Not Found**: Verify the dictionary file path is correct
- **Slow Validation**: Check cache hit rates and consider preloading common words
- **Rate Limit Errors**: Adjust rate limit settings if legitimate use cases require higher limits
- **Memory Pressure**: Reduce cache size or TTL values if memory usage is excessive
- **Invalid Words Accepted**: Check variation and lemmatization settings
- **Valid Words Rejected**: Ensure dictionary is complete and properly loaded
- **Initialization Failures**: Verify file permissions and path configuration

## Advanced Usage

### Custom Dictionary Implementation
```javascript
// Creating a specialized dictionary for a specific game mode
const WordManager = require('./wordManager');
const fs = require('fs').promises;
const path = require('path');

async function createThematicDictionary(theme, outputPath) {
  // Initialize the word manager
  const wordManager = new WordManager();
  await wordManager.initialize();
  
  // Get all words from the main dictionary
  const allWords = Array.from(wordManager._state.dictionary);
  
  // Filter words based on theme
  let thematicWords;
  
  switch (theme) {
    case 'animals':
      thematicWords = allWords.filter(word => 
        ANIMAL_CATEGORIES.some(category => word.includes(category))
      );
      break;
    case 'food':
      thematicWords = allWords.filter(word => 
        FOOD_CATEGORIES.some(category => word.includes(category))
      );
      break;
    case 'technology':
      thematicWords = allWords.filter(word => 
        TECH_CATEGORIES.some(category => word.includes(category))
      );
      break;
    default:
      throw new Error(`Unknown theme: ${theme}`);
  }
  
  // Write filtered dictionary to file
  await fs.writeFile(
    path.resolve(outputPath, `${theme}_dictionary.txt`),
    thematicWords.join('\n'),
    'utf8'
  );
  
  return {
    theme,
    wordCount: thematicWords.length,
    path: path.resolve(outputPath, `${theme}_dictionary.txt`)
  };
}

// Theme category keywords
const ANIMAL_CATEGORIES = ['cat', 'dog', 'bird', 'fish', 'mammal', 'reptile'];
const FOOD_CATEGORIES = ['fruit', 'vegetable', 'meat', 'dessert', 'grain'];
const TECH_CATEGORIES = ['computer', 'digital', 'software', 'hardware', 'internet'];

// Usage
async function setupThematicGameMode() {
  try {
    const animalDict = await createThematicDictionary('animals', './data');
    
    // Create specialized word manager with this dictionary
    const animalWordManager = new WordManager(animalDict.path);
    await animalWordManager.initialize();
    
    console.log(`Initialized themed dictionary with ${animalWordManager.getDictionarySize()} animal words`);
    
    // Use for a special game mode
    return animalWordManager;
  } catch (error) {
    console.error('Failed to set up thematic game mode:', error);
    throw error;
  }
}
```

### Advanced Word Analysis
```javascript
// Implementing advanced word analysis for game insights
const WordManager = require('./wordManager');

class WordAnalytics {
  constructor(wordManager) {
    this.wordManager = wordManager;
    this.analysisCache = new Map();
  }
  
  async initialize() {
    if (!this.wordManager.isInitialized) {
      await this.wordManager.initialize();
    }
  }
  
  async analyzeWord(word) {
    // Check cache first
    if (this.analysisCache.has(word)) {
      return this.analysisCache.get(word);
    }
    
    const lowerWord = word.toLowerCase();
    
    // Get word stats
    const stats = await this.wordManager.getWordStats(lowerWord);
    
    // Get variations
    const variations = await this.wordManager.getAllWordVariations(lowerWord);
    
    // Calculate complexity score
    const complexityScore = this._calculateComplexity(lowerWord);
    
    // Calculate distinctiveness (how unique the letters are)
    const distinctiveness = this._calculateDistinctiveness(lowerWord);
    
    // Calculate game value (how valuable in gameplay)
    const gameValue = this._calculateGameValue(lowerWord, stats);
    
    // Assemble analysis
    const analysis = {
      word: lowerWord,
      length: lowerWord.length,
      stats: stats || { totalAttempts: 0, successfulAttempts: 0, failedAttempts: 0 },
      variations: variations || [],
      metrics: {
        complexity: complexityScore,
        distinctiveness: distinctiveness,
        gameValue: gameValue
      },
      categories: this._categorizeWord(lowerWord)
    };
    
    // Cache the analysis
    this.analysisCache.set(lowerWord, analysis);
    
    return analysis;
  }
  
  async compareWords(word1, word2) {
    const analysis1 = await this.analyzeWord(word1);
    const analysis2 = await this.analyzeWord(word2);
    
    return {
      word1: analysis1,
      word2: analysis2,
      comparison: {
        lengthDiff: analysis1.length - analysis2.length,
        complexityDiff: analysis1.metrics.complexity - analysis2.metrics.complexity,
        distinctivenessDiff: analysis1.metrics.distinctiveness - analysis2.metrics.distinctiveness,
        gameValueDiff: analysis1.metrics.gameValue - analysis2.metrics.gameValue,
        sharedCategories: analysis1.categories.filter(c => analysis2.categories.includes(c)),
        matchProbability: this._calculateMatchProbability(analysis1, analysis2)
      }
    };
  }
  
  // Helper methods
  _calculateComplexity(word) {
    // Factor in uncommon letters, length, consonant clusters
    const uncommonLetters = 'jkqvwxyz';
    let score = 0;
    
    // Add points for length
    score += Math.min(10, word.length) * 0.2;
    
    // Add points for uncommon letters
    for (const letter of word) {
      if (uncommonLetters.includes(letter)) {
        score += 0.5;
      }
    }
    
    // Add points for consonant clusters
    const consonantClusters = word.match(/[bcdfghjklmnpqrstvwxyz]{3,}/g) || [];
    score += consonantClusters.length * 0.7;
    
    return Math.min(10, score);
  }
  
  _calculateDistinctiveness(word) {
    // Ratio of unique letters to total letters
    const uniqueLetters = new Set(word.split('')).size;
    return uniqueLetters / word.length;
  }
  
  _calculateGameValue(word, stats) {
    // How valuable is this word in gameplay
    let value = 0;
    
    // Length value (medium words are most valuable)
    const lengthValue = word.length <= 8 ? word.length : (16 - word.length);
    value += lengthValue * 0.5;
    
    // Statistical value
    if (stats && stats.totalAttempts > 0) {
      // Words with balanced success/failure are most interesting
      const successRate = stats.successfulAttempts / stats.totalAttempts;
      const balancedRate = Math.abs(successRate - 0.5);
      value += (1 - balancedRate) * 5; // 0-5 points, max for 50% success rate
    }
    
    return Math.min(10, value);
  }
  
  _categorizeWord(word) {
    const categories = [];
    
    // Basic categories based on word properties
    if (word.length <= 3) categories.push('short');
    else if (word.length >= 8) categories.push('long');
    
    if (/^[aeiou]/.test(word)) categories.push('vowel-start');
    if (/[aeiou]$/.test(word)) categories.push('vowel-end');
    
    // More specific categories would be added based on dictionary lookups
    
    return categories;
  }
  
  _calculateMatchProbability(analysis1, analysis2) {
    // Calculate probability that players would match these words
    // Factors: shared letters, similar length, semantic relationship
    
    // Shared letters factor
    const letters1 = new Set(analysis1.word.split(''));
    const letters2 = new Set(analysis2.word.split(''));
    const sharedLetters = [...letters1].filter(l => letters2.has(l)).length;
    const letterSimilarity = sharedLetters / Math.max(letters1.size, letters2.size);
    
    // Length similarity
    const lengthSimilarity = 1 - (Math.abs(analysis1.length - analysis2.length) / Math.max(analysis1.length, analysis2.length));
    
    // Category similarity
    const sharedCategories = analysis1.categories.filter(c => analysis2.categories.includes(c)).length;
    const categorySimilarity = sharedCategories / Math.max(analysis1.categories.length, analysis2.categories.length);
    
    // Combined probability (weighted)
    return (letterSimilarity * 0.4) + (lengthSimilarity * 0.3) + (categorySimilarity * 0.3);
  }
} 