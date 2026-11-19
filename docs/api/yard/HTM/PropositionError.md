# Class HTM::PropositionError <a id="class-HTM-PropositionError"></a>

|  |  |
| --- | --- |
| **Inherits** | [HTM::Error](Error.md) |
| **Defined in** | lib/htm/errors.rb |

Raised when proposition extraction fails

Common causes:
*   LLM provider API errors
*   Invalid proposition response format
*   Network connectivity issues
*   Model not available

Note: This error is distinct from CircuitBreakerOpenError. PropositionError
indicates a single failure, while CircuitBreakerOpenError indicates repeated
failures have triggered protective circuit breaking.
