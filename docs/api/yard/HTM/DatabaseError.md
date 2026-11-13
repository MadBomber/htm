# Class HTM::DatabaseError <a id="class-HTM-DatabaseError"></a>

|  |  |
| --- | --- |
| **Inherits** | [HTM::Error](Error.md) |
| **Defined in** | lib/htm/errors.rb |

Raised when database operations fail

Common causes:
*   Connection failures
*   Query syntax errors
*   Constraint violations
*   Extension not installed (pgvector, pg_trgm)
