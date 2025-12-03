# frozen_string_literal: true

# HTM (Hierarchical Temporal Memory) error classes
#
# All HTM errors inherit from HTM::Error, allowing you to catch
# all HTM-related errors with a single rescue clause.
#
# @example Catching all HTM errors
#   begin
#     htm.remember("some content")
#   rescue HTM::Error => e
#     logger.error "HTM error: #{e.message}"
#   end
#
# @example Catching specific errors
#   begin
#     htm.forget(node_id, soft: false)
#   rescue HTM::NotFoundError
#     puts "Node not found"
#   rescue HTM::ValidationError
#     puts "Invalid input"
#   end
#
class HTM
  # Base error class for all HTM errors
  #
  # All custom HTM errors inherit from this class, providing a common
  # ancestor for error handling.
  #
  class Error < StandardError; end

  # Raised when input validation fails
  #
  # Common causes:
  # - Empty or nil content for remember()
  # - Content exceeding maximum size limit
  # - Invalid tag format
  # - Invalid recall strategy
  # - Invalid timeframe format
  #
  # @example
  #   htm.remember("")  # => raises ValidationError
  #   htm.remember("x", tags: ["INVALID!"])  # => raises ValidationError
  #
  class ValidationError < Error; end

  # Raised when system resources are exhausted
  #
  # Common causes:
  # - Working memory token limit exceeded
  # - Database connection pool exhausted
  # - Memory allocation failures
  #
  class ResourceExhaustedError < Error; end

  # Raised when a requested resource cannot be found
  #
  # Common causes:
  # - Node ID does not exist
  # - Robot not registered
  # - File source not found
  #
  # @example
  #   htm.forget(999999)  # => raises NotFoundError if node doesn't exist
  #
  class NotFoundError < Error; end

  # Raised when embedding generation fails
  #
  # Common causes:
  # - LLM provider API errors
  # - Invalid embedding response format
  # - Network connectivity issues
  # - Model not available
  #
  # Note: This error is distinct from CircuitBreakerOpenError.
  # EmbeddingError indicates a single failure, while CircuitBreakerOpenError
  # indicates repeated failures have triggered protective circuit breaking.
  #
  class EmbeddingError < Error; end

  # Raised when tag extraction fails
  #
  # Common causes:
  # - LLM provider API errors
  # - Invalid tag response format
  # - Network connectivity issues
  # - Model not available
  #
  # Note: This error is distinct from CircuitBreakerOpenError.
  # TagError indicates a single failure, while CircuitBreakerOpenError
  # indicates repeated failures have triggered protective circuit breaking.
  #
  class TagError < Error; end

  # Raised when proposition extraction fails
  #
  # Common causes:
  # - LLM provider API errors
  # - Invalid proposition response format
  # - Network connectivity issues
  # - Model not available
  #
  # Note: This error is distinct from CircuitBreakerOpenError.
  # PropositionError indicates a single failure, while CircuitBreakerOpenError
  # indicates repeated failures have triggered protective circuit breaking.
  #
  class PropositionError < Error; end

  # Raised when database operations fail
  #
  # Common causes:
  # - Connection failures
  # - Query syntax errors
  # - Constraint violations
  # - Extension not installed (pgvector, pg_trgm)
  #
  class DatabaseError < Error; end

  # Raised when a database query exceeds the configured timeout
  #
  # Default timeout is 30 seconds. Configure via db_query_timeout parameter
  # when initializing HTM.
  #
  # @example Handling timeout
  #   begin
  #     htm.recall("complex query", strategy: :hybrid)
  #   rescue HTM::QueryTimeoutError
  #     # Retry with simpler query or smaller limit
  #   end
  #
  class QueryTimeoutError < DatabaseError; end

  # Raised when an operation is not authorized
  #
  # Reserved for future multi-tenant scenarios where access control
  # may restrict certain operations.
  #
  class AuthorizationError < Error; end

  # Raised when circuit breaker is open due to repeated failures
  #
  # The circuit breaker pattern protects against cascading failures when
  # external LLM services are unavailable. When too many consecutive
  # failures occur, the circuit "opens" and subsequent calls fail fast
  # without attempting the operation.
  #
  # Circuit states:
  # - :closed - Normal operation, requests flow through
  # - :open - Too many failures, requests fail immediately
  # - :half_open - Testing if service recovered
  #
  # After a reset timeout (default: 60 seconds), the circuit transitions
  # to half-open and tests if the service has recovered.
  #
  # @example Handling circuit breaker
  #   begin
  #     htm.remember("new content")
  #   rescue HTM::CircuitBreakerOpenError
  #     # LLM service unavailable, but node is still saved
  #     # Embeddings/tags will be generated later when service recovers
  #   end
  #
  # @see HTM::CircuitBreaker
  # @see HTM::Observability.circuit_breaker_stats
  #
  class CircuitBreakerOpenError < Error; end
end
