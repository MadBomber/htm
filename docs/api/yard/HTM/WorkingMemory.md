# Class: HTM::WorkingMemory
**Inherits:** Object
    

Working Memory - Token-limited active context for immediate LLM use

WorkingMemory manages the active conversation context within token limits.
When full, it evicts less important or older nodes back to long-term storage.

Thread Safety: All public methods are protected by a mutex to ensure safe
concurrent access from multiple threads.


# Attributes
## max_tokens[RW] {: #attribute-i-max_tokens }
Returns the value of attribute max_tokens.


# Instance Methods
## add(key, value, token_count:, access_count:0, last_accessed:nil, from_recall:false) {: #method-i-add }
Add a node to working memory

**`@param`** [String] Node identifier

**`@param`** [String] Node content

**`@param`** [Integer] Number of tokens in this node

**`@param`** [Integer] Access count from long-term memory (default: 0)

**`@param`** [Time, nil] Last access time from long-term memory

**`@param`** [Boolean] Whether this node was recalled from long-term memory

**`@return`** [void] 

## assemble_context(strategy:, max_tokens:nil) {: #method-i-assemble_context }
Assemble context string for LLM

**`@param`** [Symbol] Assembly strategy (:recent, :frequent, :balanced)
- :recent - Most recently accessed (LRU)
- :frequent - Most frequently accessed (LFU)
- :balanced - Combines frequency × recency

**`@param`** [Integer, nil] Optional token limit

**`@return`** [String] Assembled context

## evict_to_make_space(needed_tokens) {: #method-i-evict_to_make_space }
Evict nodes to make space

Uses LFU + LRU strategy: Least Frequently Used + Least Recently Used Nodes
with low access count and old timestamps are evicted first

**`@param`** [Integer] Number of tokens needed

**`@return`** [Array<Hash>] Evicted nodes

## has_space?(token_count) {: #method-i-has_space? }
Check if there's space for a node

**`@param`** [Integer] Number of tokens needed

**`@return`** [Boolean] true if space available

## initialize(max_tokens:) {: #method-i-initialize }
Initialize working memory

**`@param`** [Integer] Maximum tokens allowed in working memory

**`@return`** [WorkingMemory] a new instance of WorkingMemory

## node_count() {: #method-i-node_count }
Get node count

**`@return`** [Integer] Number of nodes in working memory

## remove(key) {: #method-i-remove }
Remove a node from working memory

**`@param`** [String] Node identifier

**`@return`** [void] 

## token_count() {: #method-i-token_count }
Get current token count

**`@return`** [Integer] Total tokens in working memory

## utilization_percentage() {: #method-i-utilization_percentage }
Get utilization percentage

**`@return`** [Float] Percentage of working memory used

