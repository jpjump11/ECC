---
name: agent-activity-theater
description: Build a character-themed, animated dashboard that visualizes a multi-agent / swarm system working in real time, with a paired live log stream. Composes dashboard-builder + motion-ui + frontend-design-direction for the "watch the agents work" use case.
origin: ECC
tools: Read, Write, Edit, Bash, Grep, Glob
---

# Agent Activity Theater

A focused recipe for turning a multi-agent system's event stream into a
**theater**: each agent is a character, every unit of work is a visible
animation, and a log column streams the same events as text. Use it when a plain
metrics dashboard fails the "can I see it working?" test.

Composes the existing ECC skills rather than replacing them:
`dashboard-builder` (layout + data wiring), `motion-ui` (the animation language),
`frontend-design-direction` (a distinctive, non-generic theme).

## When to Activate

- Visualizing a swarm / multi-agent / pipeline system as it runs (trading bots,
  research swarms, job queues, agent orchestrators).
- The ask is "show the work moving" / "character theme" / "see it animate", not
  just charts and counters.
- You want logs shown **alongside** the visualization, not on a separate page.

## How It Works

1. **Find the event source first.** Locate the system's tick/step record (e.g. a
   `TickReport[]` on a `/api/status` endpoint, an SSE feed, or a JSONL log).
   Everything below is driven by diffing that stream. Never invent a parallel
   data path.
2. **One character per agent.** Map each agent id to a `{ name, role, glyph }`.
   Handle composite ids (`a+b`) by taking the first component. Render avatar
   cards in a proportioned grid (the "pantheon").
3. **Animate the flow, not just the state.** Per new tick: light up the agents
   that proposed, emit particles along a lane through the pipeline stages
   (scan → aggregate → gate → execute), flash the gate green/red on
   accept/reject, flare on execution. Stagger the steps (~90ms apart) so motion
   reads as a sequence, not a flash.
4. **Pair the log.** A scrolling, color-coded log column emits one line per event
   (scan / propose / accept / reject / execute / error), timestamped, auto-
   scrolling, capped (~220 lines). Same events as the animation — one source.
5. **Status header.** Run state (with a pulsing live dot / red kill glow), mode,
   tick, the headline metric, and any safety state (drawdown, kill switch).
6. **Self-contained + mock fallback.** Ship one HTML file (no build step). Poll
   the real endpoint; if it is unreachable (opened as a file), drive a built-in
   mock feed so the theater animates standalone for design iteration.
7. **Distinctive theme.** Pick a concrete motif (per `frontend-design-direction`)
   and commit to it — type, palette, texture, iconography. Avoid the generic
   dark-card AI-dashboard look.

## Anti-patterns

- A second data path / fake state that drifts from the real system.
- Motion with no meaning (decorative spinners) instead of motion that maps to
  real events.
- Logs on a different screen — the point is to see text and motion together.
- Per-tick full re-render (kills the animation); diff and animate deltas.

## Example

Canonical implementation: the **Hermes Swarm Theater** in the Polymarket swarm
(`poly-sdk` `dashboard/public/hermes.html`, served at `/theater`). It visualizes
nine trading agents as Greek-messenger characters, reads real `TickReport[]` from
`/api/status` (+ realized PnL from `/api/performance`), animates
scan → aggregate → risk-gate → execute with a canvas particle lane, and streams
the same events into an "Oracle Log" column — with a mock feed fallback so it
animates when opened directly. ~445 lines, single file, zero dependencies.
