# Current implementation direction

Read [CLAUDE_IMPLEMENTATION_HANDOFF.md](CLAUDE_IMPLEMENTATION_HANDOFF.md) first.
It contains the user's September 15 map/gameplay brief, recording findings, complete plan,
current working baseline, implementation sequence, and acceptance criteria.

The active default Rojo project is gameplay-only on the user's existing baseplate.
`lemonade-game/Gameplay/WorldLayout.luau` is its WorldLayout module, NOT the legacy
ServerScriptService/WorldLayout.luau. Preserve this baseline while building the new map in
a separate project. The older Fivefold Sanctuary layout is historical, not the new target.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
