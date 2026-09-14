---
name: roblox-map-design
description: Design Roblox maps, levels, obbies, arenas, and open worlds with structured beat sheets and procedural placement scripts. Use when building a new map, level, obby course, arena, dungeon, or open-world zone. Triggers on map design, level layout, obby builder, arena design, world building, or spatial game design for Roblox.
---

# Roblox Map & Level Design

Design maps and levels with structured gameplay beats, then generate procedural placement scripts.

## Spatial Beat Structure

Every map MUST follow this beat structure:

| Beat | Purpose | Questions to Answer |
|------|---------|-------------------|
| **Entrance Read** | First 3 seconds of player experience | What do they see? What's the visual hook? Where's the spawn? |
| **Teach** | Introduce one mechanic without text tutorial | What action do they discover naturally? What's the failure state? |
| **Escalation (×3)** | Three increasing-difficulty beats | What new challenge is added each time? Where's the recovery space? |
| **Checkpoint** | Safe reset point | How far back does failure send them? What's the respawn animation? |
| **Mastery Path** | Optional advanced route | What does a skilled player do differently? What reward do they get? |
| **Exit / Handoff** | Transition to next area or win state | What's the final beat? How does the player know they're done? |

## Map Design Rules

- **Gameplay structure FIRST, theme SECOND.** "A 12-stage obby spiraling up a wizard tower, checkpoints every 3 stages, secret room behind stage 7" beats "a cool magical tower with neon colors."
- Specify: number of stages/zones, checkpoint frequency, difficulty ramp, kill zones, recovery areas, secret content, and final goal.
- For arenas: specify symmetry, contested zones, flanking routes, cover density, spawn separation distance, and destructible elements.
- For open worlds: define district boundaries, travel time between zones, landmark density, and vertical layering (underground / street / rooftop).
- **Never** just list decorations. Every spatial element must serve a gameplay purpose (cover, pathing, sightline break, reward placement).

## Output Format

When designing a map, return all four:

1. **Top-down layout description** — zone by zone, with dimensions in studs
2. **Beat sheet** — using the table above, filled in for the specific map
3. **Structural Luau script** — procedurally places key parts (platforms, kill bricks, checkpoints, spawn points) with correct Vector3 positions, sizes, and materials. Label this script `ServerScriptService`.
4. **Playtest checklist** — 5 specific things to verify in Studio

## Genre-Specific Spatial Patterns

For detailed patterns, read the appropriate reference:
- **Obby** → [references/obby-patterns.md](references/obby-patterns.md)
- **Arena / Combat** → [references/arena-patterns.md](references/arena-patterns.md)
- **Open World** → [references/open-world-patterns.md](references/open-world-patterns.md)
- **Tycoon** → [references/tycoon-patterns.md](references/tycoon-patterns.md)

## Constraints

- All structural scripts use `Script` type in `ServerScriptService`
- Use `task.wait()`, `task.spawn()`, `task.delay()` — NEVER `wait()`, `spawn()`, `delay()`
- Label all tuning values: `-- [TUNING]: value`
- Recommend the user adjust visual positions in Studio — scripts provide the structural skeleton
- Max ~100 lines per script; split larger maps into zone scripts
