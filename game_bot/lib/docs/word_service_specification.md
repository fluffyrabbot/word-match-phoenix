# WordService Module Specification

## Overview

The `GameBot.Domain.WordService` module is responsible for managing words used in the WordMatch game mode. It provides functionality for loading dictionaries, validating words, generating random words, and matching word pairs with support for variations.

## Core Functionality

The WordService must implement the following core functionality:

1. Dictionary management - loading and validating word lists
2. Word validation - checking if a word exists in the dictionary
3. Random word generation - selecting random words for gameplay
4. Word matching - determining if two words match according to game rules
5. Word variations - handling alternative spellings and forms

## Explicitly Excluded Functionality

The following features are explicitly excluded from the WordService implementation:

1. Word statistics tracking
2. Word difficulty assessment
3. Word complexity measurement
4. Similarity scoring between words (only binary success/failure matching)

## API Specification

### Setup and Configuration

```elixir
@doc """
Initializes the WordService with the specified dictionary.
"""
@spec start_link(options :: keyword()) :: GenServer.on_start()

@doc """
Loads a dictionary from the specified file path.
Returns {:ok, count} on success, {:error, reason} on failure.
"""
@spec load_dictionary(path :: String.t()) :: {:ok, integer()} | {:error, term()}

@doc """
Reloads the dictionary, refreshing any cached data.
"""
@spec reload_dictionary() :: {:ok, integer()} | {:error, term()}
```

### Word Validation

```elixir
@doc """
Validates if a word exists in the dictionary.
Returns true if the word exists, false otherwise.
"""
@spec valid_word?(word :: String.t()) :: boolean()
```

### Word Generation

```elixir
@doc """
Generates a random word suitable for gameplay.
"""
@spec random_word() :: String.t()

@doc """
Generates a pair of random words for WordMatch gameplay.
"""
@spec random_word_pair() :: {String.t(), String.t()}
```

### Word Matching

```elixir
@doc """
Determines if two words are considered a match according to game rules.
Returns true if words match, false otherwise.
"""
@spec match?(word1 :: String.t(), word2 :: String.t()) :: boolean()
```

### Word Variations

```elixir
@doc """
Returns all acceptable variations of a word.
Includes plurals, regional spellings, etc.
"""
@spec variations(word :: String.t()) :: [String.t()]

@doc """
Returns the base form (lemma) of a word.
"""
@spec base_form(word :: String.t()) :: String.t()
```

## Implementation Considerations

### State Management

The WordService will be implemented as a GenServer that manages:

- The dictionary of valid words
- Word variations and relationships
- Cache of validation and matching results

### Dictionary Format

The dictionary should be loaded from a text file with the following format:
- One word per line
- Dictionary file located at `priv/dictionaries/dictionary.txt`

### Word Matching Rules

Word matching should consider:

1. **Exact matches** - The words are identical (case-insensitive)
2. **Variations** - One word is a variation of the other (US/UK spelling)
3. **Singular/Plural** - One word is the singular/plural form of the other
4. **Lemmatization** - Words share the same base form or lemma

### Performance Optimization

The WordService should implement:

1. **ETS-based caching** - Store validation and matching results
2. **Efficient dictionary storage** - Optimize for lookup speed

### Error Handling

The WordService should implement robust error handling for:

1. **Dictionary loading failures** - File not found, corrupted data
2. **Invalid word submissions** - Properly reject invalid words

## Testing Strategy

Testing should cover:

1. **Unit tests** - Validate core functionality (word validation, matching)
2. **Property tests** - Verify consistency of matching algorithms
3. **Integration tests** - Verify interaction with game modes

## Implementation Phases

1. **Phase 1: Basic Dictionary Operations**
   - Dictionary loading and validation
   - Basic word validation

2. **Phase 2: Word Matching Logic**
   - Implement matching algorithms
   - Add variation support

3. **Phase 3: Advanced Matching Features**
   - Add lemmatization
   - Implement singular/plural matching

4. **Phase 4: Performance Optimization**
   - Add ETS-based caching
   - Implement efficient lookup algorithms 