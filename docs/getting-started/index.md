# Getting Started

Welcome to HTM (Hierarchical Temporal Memory)! This section will help you get up and running quickly.

## Overview

HTM provides intelligent memory management for LLM-based applications (robots) with a two-tier architecture:

- **Long-term Memory**: Durable PostgreSQL storage with vector embeddings for semantic search
- **Working Memory**: Token-limited in-memory context for immediate LLM use

## What You'll Learn

<div class="grid cards" markdown>

-   :material-download:{ .lg .middle } **Installation**

    ---

    Set up HTM in your Ruby project with all required dependencies including PostgreSQL, pgvector, and Ollama.

    [:octicons-arrow-right-24: Install HTM](installation.md)

-   :material-rocket-launch:{ .lg .middle } **Quick Start**

    ---

    Build your first memory-enabled robot in minutes with practical examples and code snippets.

    [:octicons-arrow-right-24: Get started](quick-start.md)

</div>

## Prerequisites

Before installing HTM, ensure you have:

- **Ruby 3.1+** - HTM uses modern Ruby features
- **PostgreSQL 14+** - With pgvector and pg_trgm extensions
- **Ollama** (optional) - For local embedding generation

## Next Steps

1. **[Install HTM](installation.md)** - Set up the gem and database
2. **[Quick Start](quick-start.md)** - Create your first memory-enabled robot
3. **[Architecture Overview](../architecture/overview.md)** - Understand how HTM works
4. **[Guides](../guides/index.md)** - Deep dive into specific features
