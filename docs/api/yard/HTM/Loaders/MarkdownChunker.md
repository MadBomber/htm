# Class HTM::Loaders::MarkdownChunker <a id="class-HTM-Loaders-MarkdownChunker"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/loaders/markdown_chunker.rb |

Markdown-aware text chunker using Baran

Wraps Baran::MarkdownSplitter to provide intelligent text chunking that
respects markdown structure (headers, code blocks, etc.).

**@example Basic usage**
```ruby
chunker = MarkdownChunker.new
chunks = chunker.chunk("# Header\n\nParagraph text.\n\n## Subheader\n\nMore text.")
# => ["# Header\n\nParagraph text.", "## Subheader\n\nMore text."]
```

**@example With custom chunk size**
```ruby
chunker = MarkdownChunker.new(chunk_size: 512, chunk_overlap: 50)
chunks = chunker.chunk(long_text)
```

**@example With full metadata (includes cursor positions)**
```ruby
chunker = MarkdownChunker.new
chunks = chunker.chunk_with_metadata(text)
# => [{ text: "...", cursor: 0, metadata: nil }, { text: "...", cursor: 156, metadata: nil }]
```

## Attributes
### `chunk_overlap` [R] <a id="attribute-i-chunk_overlap"></a> <a id="chunk_overlap-instance_method"></a>
Returns the value of attribute chunk_overlap.

### `chunk_size` [R] <a id="attribute-i-chunk_size"></a> <a id="chunk_size-instance_method"></a>
Returns the value of attribute chunk_size.

## Public Instance Methods
### `chunk(text)` <a id="method-i-chunk"></a> <a id="chunk-instance_method"></a>
Split text into markdown-aware chunks (text only)
- **`@param`** `text` [String] Text to chunk
- **`@return`** [Array<String>] Array of text chunks

### `chunk_with_metadata(text)` <a id="method-i-chunk_with_metadata"></a> <a id="chunk_with_metadata-instance_method"></a>
Split text and return full chunk data (with cursor positions)

Returns Baran's full output including:
*   :text [String] The chunk content
*   :cursor [Integer] Character offset where chunk starts in original text
- **`@param`** `text` [String] Text to chunk
- **`@return`** [Array<Hash>] Array of chunk hashes with :text and :cursor

### `initialize(chunk_size: nil, chunk_overlap: nil)` <a id="method-i-initialize"></a> <a id="initialize-instance_method"></a>
- **`@param`** `chunk_size` [Integer] Maximum characters per chunk (default: from config or 1024)
- **`@param`** `chunk_overlap` [Integer] Character overlap between chunks (default: from config or 64)
- **`@return`** [MarkdownChunker] a new instance of MarkdownChunker
