# HTM User Guides

Welcome to the HTM (Hierarchical Temporary Memory) user guide collection. These guides will help you understand and effectively use HTM for building intelligent LLM-based applications with persistent memory.

## What is HTM?

HTM is an intelligent memory management system for LLM robots that implements a two-tier architecture:

- **Working Memory**: Token-limited active context for immediate LLM use
- **Long-term Memory**: Durable PostgreSQL storage for permanent knowledge

HTM enables your robots to recall context from past conversations using RAG (Retrieval-Augmented Generation), creating continuity across sessions and enabling sophisticated multi-robot collaboration.

## Guide Categories

### Getting Started

Perfect for developers new to HTM or those building their first application.

- [**Getting Started Guide**](getting-started.md) - Your first HTM application, basic concepts, and common patterns

### Core Operations

Learn how to work with HTM's memory system effectively.

- [**Adding Memories**](adding-memories.md) - How to store different types of information in HTM
- [**Recalling Memories**](recalling-memories.md) - Search strategies and retrieval techniques
- [**Working Memory Management**](working-memory.md) - Understanding token limits and eviction
- [**Long-term Memory**](long-term-memory.md) - Database operations and maintenance

### Advanced Features

Dive deeper into HTM's powerful capabilities.

- [**Multi-Robot Usage**](multi-robot.md) - Building hive mind systems with multiple robots
- [**Search Strategies**](search-strategies.md) - Vector, full-text, and hybrid search
- [**Context Assembly**](context-assembly.md) - Creating optimized context for LLMs

## Learning Path

We recommend the following progression:

1. **Start Here**: [Getting Started Guide](getting-started.md)
   - Understand HTM's architecture
   - Build your first application
   - Learn basic operations

2. **Core Skills**: Memory Operations
   - [Adding Memories](adding-memories.md) - Store information effectively
   - [Recalling Memories](recalling-memories.md) - Retrieve what you need
   - [Context Assembly](context-assembly.md) - Use memories with LLMs

3. **Deep Understanding**: Memory Management
   - [Working Memory](working-memory.md) - Token management
   - [Long-term Memory](long-term-memory.md) - Database operations
   - [Search Strategies](search-strategies.md) - Optimize retrieval

4. **Advanced Topics**: Multi-Robot Systems
   - [Multi-Robot Usage](multi-robot.md) - Build collaborative systems

## Quick Reference

### Common Tasks

- **Initialize HTM**: See [Getting Started](getting-started.md#basic-initialization)
- **Add a memory**: See [Adding Memories](adding-memories.md#basic-usage)
- **Search for memories**: See [Recalling Memories](recalling-memories.md#basic-recall)
- **Create LLM context**: See [Context Assembly](context-assembly.md#basic-usage)
- **Monitor memory usage**: See [Working Memory](working-memory.md#monitoring-utilization)
- **Multi-robot setup**: See [Multi-Robot Usage](multi-robot.md#setting-up-multiple-robots)

### Memory Types

HTM supports six memory types, each optimized for different use cases:

| Type | Purpose | Example |
|------|---------|---------|
| `:fact` | Immutable facts | "User's name is Alice" |
| `:context` | Conversation state | "Discussing database architecture" |
| `:code` | Code snippets | "Ruby function for parsing dates" |
| `:preference` | User preferences | "Prefers dark theme" |
| `:decision` | Design decisions | "Chose PostgreSQL for storage" |
| `:question` | Unresolved questions | "Should we add caching?" |

### Search Strategies

| Strategy | Method | Best For |
|----------|--------|----------|
| Vector | Semantic similarity | Conceptual searches, related topics |
| Full-text | Keyword matching | Exact terms, specific phrases |
| Hybrid | Combined approach | Best overall accuracy |

## Getting Help

- **Examples**: Check the `examples/` directory in the HTM repository
- **API Reference**: See the [API documentation](../api/index.md)
- **Tests**: Look at `test/` directory for usage examples
- **Issues**: Report bugs on [GitHub](https://github.com/madbomber/htm/issues)

## Documentation Conventions

Throughout these guides, you'll see these admonitions:

!!! tip
    Helpful advice and best practices

!!! warning
    Important warnings about potential issues

!!! note
    Additional information and context

!!! example
    Code examples and usage demonstrations

## Next Steps

Ready to get started? Head over to the [Getting Started Guide](getting-started.md) to build your first HTM application.
