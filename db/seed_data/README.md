# HTM Seed Data

This directory contains markdown files used to seed the HTM database with sample data.

## Configuration

The seeding process uses environment variables for configuration. All settings have sensible defaults:

### LLM Provider Settings

- `HTM_EMBEDDING_PROVIDER` - Embedding provider (default: `ollama`)
- `HTM_EMBEDDING_MODEL` - Embedding model (default: `nomic-embed-text`)
- `HTM_EMBEDDING_DIMENSIONS` - Embedding dimensions (default: `768`)
- `HTM_TAG_PROVIDER` - Tag extraction provider (default: `ollama`)
- `HTM_TAG_MODEL` - Tag extraction model (default: `gemma3`)
- `OLLAMA_URL` - Ollama server URL (default: `http://localhost:11434`)

### Timeout Settings

- `HTM_EMBEDDING_TIMEOUT` - Embedding generation timeout in seconds (default: `120`)
- `HTM_TAG_TIMEOUT` - Tag generation timeout in seconds (default: `180`)
- `HTM_CONNECTION_TIMEOUT` - LLM connection timeout in seconds (default: `30`)

### Database Settings

- `HTM_DBURL` - Full PostgreSQL connection URL (required)
- Or individual settings: `HTM_DBHOST`, `HTM_DBPORT`, `HTM_DBNAME`, `HTM_DBUSER`, `HTM_DBPASS`

### Other Settings

- `HTM_ROBOT_NAME` - Name for the seeding robot (default: `"Seed Robot"`)

## Format

All `.md` files in this directory will be automatically processed by `db/seeds.rb`.

Each markdown file should follow this structure:

```markdown
# Title (optional, will be ignored)

## Section Name 1
Paragraph of content for this section. This entire paragraph will be stored
as a single memory node in HTM.

## Section Name 2
Another paragraph of content. Each ## header denotes a new section that will
become a separate memory node.

## Section Name 3
Content for the third section...
```

## Processing

The seeding script (`db/seeds.rb`):

1. Reads all `*.md` files from this directory
2. Parses each file looking for `## Header` sections
3. Extracts the paragraph(s) following each header
4. Creates an HTM memory node for each section
5. Uses the filename (without `.md`) as the `source` field
6. Automatically generates embeddings and hierarchical tags for each node

## Current Seed Data

- **states.md**: Interesting facts about all 50 US states
- **presidents.md**: Interesting facts about all 45 US presidents

## Adding New Seed Data

To add new seed data:

1. Create a new `.md` file in this directory
2. Follow the format above with `## Header` sections
3. Run `rake htm:db:seed` to populate the database

The filename (without extension) will be used as the source identifier for all nodes
created from that file.

## Example

Given a file `countries.md`:

```markdown
# World Countries

## France
France is known for the Eiffel Tower...

## Japan
Japan is an island nation...
```

Running `rake htm:db:seed` will create:
- 2 memory nodes
- Both with `source: "countries"`
- Each with embeddings (768-dimensional vectors)
- Each with hierarchical tags extracted by LLM
- Stored in the `nodes` table with full-text and vector search capabilities
