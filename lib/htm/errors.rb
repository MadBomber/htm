# frozen_string_literal: true

# HTM error classes
class HTM
  # Base error class for all HTM errors
  class Error < StandardError; end

  # Validation errors
  class ValidationError < Error; end

  # Resource exhausted errors (memory, tokens, etc.)
  class ResourceExhaustedError < Error; end

  # Resource not found errors
  class NotFoundError < Error; end

  # Embedding service errors
  class EmbeddingError < Error; end

  # Tag service errors
  class TagError < Error; end

  # Database operation errors
  class DatabaseError < Error; end

  # Query timeout errors
  class QueryTimeoutError < DatabaseError; end

  # Authorization errors
  class AuthorizationError < Error; end

  # Circuit breaker errors
  class CircuitBreakerOpenError < EmbeddingError; end
end
