# Why "Robots" Instead of "Agents"?

> "What's in a name? That which we call a rose
> By any other name would smell as sweet."
> — Shakespeare, *Romeo and Juliet*

Shakespeare argues names are arbitrary. In software, we respectfully disagree—names shape expectations and understanding. The words we choose frame how we think about systems, what we expect from them, and how we architect their capabilities.

HTM uses **robots** rather than the fashionable "agents" deliberately and thoughtfully.

## The Problem with "Agent"

The term "agent" carries philosophical baggage it cannot support:

- **Semantic overload**: User agents, software agents, real estate agents, secret agents, FBI agents, travel agents. The word means everything and therefore nothing. When you say "AI agent," what mental model does your listener construct?

- **False autonomy**: "Agent" implies genuine decision-making, independent action, perhaps even free will. These systems follow instructions. They predict the next token. They don't have *agency* in any meaningful philosophical sense. Calling them agents sets expectations the technology cannot meet.

- **The hype cycle problem**: "AI Agent" and "Agentic AI" became buzzwords in 2023-2024, often meaning nothing more than "LLM with a prompt and a while loop." We prefer terminology that will age gracefully rather than become an embarrassing artifact of a particular moment's enthusiasm.

- **Implementation reality**: Look under the hood of popular "agent" frameworks. You'll often find a system prompt, a for-loop, and some JSON parsing. Calling that an "agent" is marketing, not engineering.

## The Case for "Robot"

"Robot" has heritage, honesty, and heart:

- **Rich literary tradition**: The word comes from Karel Čapek's 1920 play *R.U.R.* (Rossum's Universal Robots), derived from Czech *robota*, meaning forced labor or drudgery. Isaac Asimov gave us the Three Laws of Robotics and decades of thoughtful exploration of robot ethics, identity, and purpose. There's a century of serious thinking about what robots are and how they should behave. "Agent" has no comparable intellectual foundation.

- **Honest about the relationship**: Robots work for us. They're tireless, reliable, and purpose-built. They don't pretend to have goals independent of their creators. This honesty about the master-worker relationship is healthier than the ambiguity of "agent."

- **Cultural resonance**: Robots are endearing. R2-D2. Wall-E. Bender. Data. The Iron Giant. Baymax. We've spent a century telling stories about robots, developing affection for them, and exploring their place alongside humanity. "Agent" has no such cultural weight—it's the language of bureaucracy and espionage.

- **Technical precision**: In HTM, each robot has an identity (`robot_id`), a name, and a history of contributions. Robots are registered in a table. They're tracked. They're *things* with identity and persistence. "Agent" suggests ephemerality; "robot" suggests durability.

## Robots in the Hive Mind

HTM's architecture reinforces the robot metaphor in a specific way: **all robots share a common long-term memory**.

This is the *hive mind* pattern. Individual robots have their own working memory—their own immediate context and focus—but they draw from and contribute to a shared pool of knowledge. Like worker bees serving a hive, each robot is both individual and part of something larger.

```
┌─────────────────────────────────────────────────────┐
│                  Shared Long-Term Memory            │
│              (The Hive Mind / Collective)           │
│                                                     │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐              │
│  │ Memory  │  │ Memory  │  │ Memory  │  ...         │
│  └─────────┘  └─────────┘  └─────────┘              │
└─────────────────────────────────────────────────────┘
        ▲              ▲              ▲
        │              │              │
   ┌────┴────┐    ┌────┴────┐    ┌────┴────┐
   │ Robot A │    │ Robot B │    │ Robot C │
   │         │    │         │    │         │
   │ Working │    │ Working │    │ Working │
   │ Memory  │    │ Memory  │    │ Memory  │
   └─────────┘    └─────────┘    └─────────┘
```

This architecture maps naturally to the robot metaphor:

- **Robots are workers**: They execute tasks, store memories, recall information
- **Robots are individuals**: Each has its own name, identity, and working context
- **Robots are collective**: They share knowledge, learn from each other's experiences
- **Robots are persistent**: They're registered, tracked, and their contributions are attributed

"Agent" suggests independence and autonomy. "Robot" suggests collaboration and purpose. HTM's robots work together, building collective intelligence. That's what the terminology should convey.

## Robots Never Forget

HTM follows a **never-forget philosophy** (see [ADR-009](../architecture/adrs/009-never-forget.md)). Memories are never truly deleted—only soft-deleted, always recoverable. This aligns with the robot metaphor:

A good robot doesn't lose your data. A good robot remembers what you told it, years later if necessary. A good robot is *reliable* in a way that ephemeral "agents" are not.

When you tell an HTM robot something important, it stores that information in the collective memory. Other robots can access it. Future robots can learn from it. The knowledge persists, attributed to the robot that first contributed it.

This is robot memory done right: durable, shared, and faithful.

## Honest Terminology, Clear Thinking

Language shapes thought. When we call these systems "agents," we prime ourselves to expect agency—goals, autonomy, perhaps even consciousness. When we call them "robots," we remind ourselves what they actually are: sophisticated tools, tireless workers, faithful servants of the instructions we give them.

HTM helps robots do their job better: remember perfectly, recall intelligently, share knowledge generously, and serve reliably. That's not agency. That's good engineering.

These are robots. Let's call them what they are.
