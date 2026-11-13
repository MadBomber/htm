# Class HTM::Loaders::MarkdownLoader <a id="class-HTM-Loaders-MarkdownLoader"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/loaders/markdown_loader.rb |

Markdown file loader

Loads markdown files into HTM long-term memory with support for:
*   YAML frontmatter parsing (stored as metadata on first chunk)
*   Paragraph-based chunking
*   Re-sync on file changes (via mtime comparison)
*   Duplicate detection via content_hash

**@example Load a single file**
```ruby
loader = MarkdownLoader.new(htm)
result = loader.load_file('/path/to/doc.md')
# => { file_path: '/path/to/doc.md', chunks_created: 5, ... }
```

**@example Load a directory**
```ruby
results = loader.load_directory('/path/to/docs', pattern: '**/*.md')
```

## Constants
### `FRONTMATTER_REGEX` <a id="constant-FRONTMATTER_REGEX"></a> <a id="FRONTMATTER_REGEX-constant"></a>
Not documented.

### `MAX_FILE_SIZE` <a id="constant-MAX_FILE_SIZE"></a> <a id="MAX_FILE_SIZE-constant"></a>
10 MB maximum file size

## Public Instance Methods
### `initialize(htm_instance, chunk_size: nil, chunk_overlap: nil)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
- **`@param`** `htm_instance` [HTM] The HTM instance to use for storing nodes
- **`@param`** `chunk_size` [Integer] Maximum characters per chunk (default: from config)
- **`@param`** `chunk_overlap` [Integer] Character overlap between chunks (default: from config)
- **`@return`** [MarkdownLoader] a new instance of MarkdownLoader

### `load_directory(path, pattern: '**/*.md', force: false)` <a id="method-i-load_directory"></a> <a id="load_directory-instance_method"></a>
Load all matching files from a directory
- **`@param`** `path` [String] Directory path
- **`@param`** `pattern` [String] Glob pattern (default: '**/*.md')
- **`@param`** `force` [Boolean] Force re-sync even if unchanged
- **`@return`** [Array<Hash>] Results for each file

### `load_file(path, force: false)` <a id="method-i-load_file"></a> <a id="load_file-instance_method"></a>
Load a single markdown file into long-term memory
- **`@param`** `path` [String] Path to markdown file
- **`@param`** `force` [Boolean] Force re-sync even if mtime unchanged
- **`@return`** [Hash] Load result with keys:
- :file_path [String] Absolute path to file
- :chunks_created [Integer] Number of new chunks created
- :chunks_updated [Integer] Number of existing chunks updated
- :chunks_deleted [Integer] Number of chunks soft-deleted
- :skipped [Boolean] True if file was unchanged and skipped
