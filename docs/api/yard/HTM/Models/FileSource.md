# Class HTM::Models::FileSource <a id="class-HTM-Models-FileSource"></a>

|  |  |
| --- | --- |
| **Inherits** | Object |
| **Defined in** | lib/htm/models/file_source.rb |

FileSource model - tracks loaded source files

Represents a file that has been loaded into HTM with its metadata. Each file
can have multiple associated nodes (chunks).

## Constants
### `DELTA_TIME` <a id="constant-DELTA_TIME"></a> <a id="DELTA_TIME-constant"></a>
Tolerance for mtime comparison to avoid false positives from precision
differences between filesystem and database timestamps

## Public Instance Methods
### `author()` <a id="method-i-author"></a> <a id="author-instance_method"></a>
Get author from frontmatter
- **`@return`** [String, nil] Author from frontmatter

### `chunks()` <a id="method-i-chunks"></a> <a id="chunks-instance_method"></a>
Get ordered chunks from this file
- **`@return`** [Array<Node>] Nodes ordered by chunk_position

### `chunks_dataset()` <a id="method-i-chunks_dataset"></a> <a id="chunks_dataset-instance_method"></a>
Alias for nodes_dataset - used for consistency with "chunks" terminology
- **`@return`** [Sequel::Dataset] Dataset of nodes from this file

### `frontmatter_tags()` <a id="method-i-frontmatter_tags"></a> <a id="frontmatter_tags-instance_method"></a>
Extract tags from frontmatter
- **`@return`** [Array<String>] Tag names from frontmatter 'tags' field

### `needs_sync?(current_mtime = nil)` <a id="method-i-needs_sync-3F"></a> <a id="needs_sync?-instance_method"></a>
Check if file needs re-sync based on mtime
- **`@param`** `current_mtime` [Time, nil] Current file modification time
- **`@return`** [Boolean] true if file needs re-sync

### `soft_delete_chunks!()` <a id="method-i-soft_delete_chunks-21"></a> <a id="soft_delete_chunks!-instance_method"></a>
Soft delete all chunks from this file, cascading to their robot_nodes and
node_tags like Node#soft_delete!
- **`@return`** [Integer] Number of chunks soft-deleted

### `title()` <a id="method-i-title"></a> <a id="title-instance_method"></a>
Get title from frontmatter
- **`@return`** [String, nil] Title from frontmatter

### `unload!()` <a id="method-i-unload-21"></a> <a id="unload!-instance_method"></a>
Soft delete all chunks and delete this source record in one transaction, so a
failure leaves both in place
- **`@return`** [Integer] Number of chunks soft-deleted

### `validate()` <a id="method-i-validate"></a> <a id="validate-instance_method"></a>
Validations
