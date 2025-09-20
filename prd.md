Rethink for oos20b — macOS Productivity App PRD (v0.1)

A day‑centric calendar + “Mind” space that plans with you, learns you (XP), works for you (XXP), and keeps every AI action staged until you commit.

⸻

0) Table of Contents
	1.	Product Vision & Strategy
	2.	Goals, Non‑Goals, Success Metrics
	3.	Personas & Core JTBD
	4.	Experience Principles
	5.	System Overview (macOS)
	6.	Feature Specification
	•	6.1 Action Bar (Single‑message, Yes/No)
	•	6.2 Calendar Planner (Day‑first; Month below)
	•	6.3 Mind Guide (Chains, Pillars, Insights)
	•	6.4 XP / XXP System (fair, global, anti‑gaming)
	•	6.5 Goals & Dream Builder
	•	6.6 Intake (Periodic Q&A)
	•	6.7 Backfill & Gap Filler
	•	6.8 Event Editing, Chains & Routines
	•	6.9 Suggestions Rail & Reschedule Queue
	•	6.10 Chips & Time Windows
	•	6.11 Onboarding
	•	6.12 Undo Everywhere
	7.	Information Architecture & Navigation
	8.	UX Flows (happy paths & edge cases)
	9.	Data Model (schemas)
	10.	AI Integration (for oos20b), prompts & confidence
	11.	Privacy, Security, and Controls
	12.	Performance & Quality Bars
	13.	Telemetry & Learning Loops
	14.	Release Plan & Milestones
	15.	Risks & Mitigations
	16.	Open Questions
	17.	Glossary
	18.	Appendices (A–E)

⸻

1) Product Vision & Strategy

Vision. Make each day feel decided. Rethink is a macOS app that fuses a precise, day‑centric calendar with a reflective “Mind” that learns your routines. It proposes confident auto‑placements, yet keeps a hard staging → commit boundary so you always stay in control.

Strategy.
	•	Opinionated day view + always‑visible month; the Mind creates chains (micro‑routines) and pillars (soft rules) that drive smart placement.
	•	Distinct signals for learning you (XP) vs working for you (XXP). Publicly comparable, anti‑gaming scoring.
	•	Minimalist conversational control: one message at a time, with inline Yes/No for any AI action.
	•	Built for a mid‑sized, fast oos20b LLM: on‑device where possible, streaming/local tool use, RAG over user memory, and calibrated confidence.

⸻

2) Goals, Non‑Goals, Success Metrics

Goals
	1.	Plan most days in < 90 seconds; reduce “empty day” anxiety.
	2.	Replace ad‑hoc to‑dos with Chains (repeatable blocks) and Pillars (soft rules) to lower planning friction.
	3.	Achieve >70% acceptance rate of proposed placements within 2 weeks of use.
	4.	Build durable user model (XP) and measurable contribution (XXP) without feeling gamified.

Non‑Goals (v1)
	•	Team collaboration, shared calendars, cross‑platform (iOS/iPadOS later).
	•	Task databases/CRMs. Rethink is day‑planning‑first.
	•	Deep email integrations.

Success Metrics (North Stars)
	•	AI Acceptance Rate: % of proposed items approved.
	•	Planning Latency: p95 from prompt → staged placements < 1.0s (local) / < 2.0s (remote).
	•	Completion Quality: ratio of backfilled vs scheduled match ≥ 0.6 by week 3.
	•	XP/XXP Health: Gini index within 0.2–0.4; low variance by persona.

⸻

3) Personas & JTBD

P1. Focused Freelancer (Kara, 29) — Wants tight day structure and quick reschedules. JTBD: “When I start my day, help me shape it in 1 minute and guard my focus.”

P2. Busy IC (Dan, 35) — Corporate calendar, many meetings. JTBD: “When gaps appear, fill them with meaningful progress.”

P3. Returning Planner (Maya, 41) — Wants reflection and momentum. JTBD: “Show me wins/blockers and make tomorrow smarter.”

⸻

4) Experience Principles
	•	Day as the stage. Month supports, Mind informs.
	•	Staged, then committed. Every AI change is explicitly confirmed.
	•	One voice, one line. Single visible message + TTS; show a brief 2‑second reflective “hmm” caption (assumptions/insight) beneath.
	•	Windows, not noise. Chips appear only in configured windows (e.g., wind‑down in evenings).
	•	Terse when sure; suggest when not. Confident auto‑place vs draggable options.

⸻

5) System Overview (macOS)
	•	App: SwiftUI app (AppKit interop where needed), universal build (Apple Silicon x86_64 fallback), sandboxed.
	•	Calendar: EventKit (read/write), CalDAV via Apple Calendar accounts.
	•	Speech: AVSpeechSynthesizer (TTS); Speech framework (dictation). Push‑to‑talk toggle in Action Bar.
	•	Notifications: UNUserNotificationCenter; actionable notifications for Yes/No.
	•	Local Store: Core Data (SQLite) for events mirror, chains, pillars, goals, telemetry. iCloud optional later.
	•	Model: oos20b served via local runtime (Metal) when available; remote fallback via encrypted endpoint. On‑device RAG over user memory (SQLite/FAISS).

⸻

6) Feature Specification

6.1 Action Bar (Single‑message, Yes/No)
	•	UI: One compact input with Text/Voice toggle. Only the latest assistant output is visible.
	•	Inline decisions: If the model proposes an action (create event, backfill edit, chain attach, pillar change), render Yes / No chips inline. No staging occurs until Yes.
	•	Reflective Caption: ephemeral (2s) “hmm” line—assumption, mood inference, or uncertainty (“seems like you’re low‑energy; buffer added”).
	•	TTS: Read the latest message and its one‑line caption. Always replace the previous line.

Acceptance
	•	Inline Yes/No must appear within 500ms of assistant output.
	•	Undo available for 10s after commit.

⸻

6.2 Calendar — Planner
	•	Layout: Day view main; month view docked below (scroll 8 months back, 30 months forward). Selecting a date updates Day.
	•	Time rails: sunrise/sunset/midnight lines; past = solid; future = outlined.
	•	Event cards: terse AI summary; click expands details. If an event has no neighbor on either end, show a + tab affordance for quick chain insertion.
	•	Placement behavior: When precise, auto‑place confidently with staging; otherwise show drag targets (e.g., “09:30, 10:00, 11:00”).
	•	Multi‑day select: select consecutive days to view AI reflection (past) or projected milestones (future) based on deltas.

Gap handling
	•	Reschedule queue (right rail badge). Persists until user resolves. Auto‑placed items appear visually distinct with inline Yes/No.

⸻

6.3 Mind — Guide (Chains, Pillars, Insights)
	•	Timeframe selector: Now, Last 2 weeks, Custom (start/end).
	•	Insights: Wins/Blockers, energy vs time heatmap, placement confidence over time.
	•	Chains area: quick chains library; defaults/templates; buffer guesser, location hints; map chain→events. After 3× completed occurrences within 30 days, show Save as routine (debounce to avoid spam).
	•	Pillars: user‑defined soft rules (windows, frequency, min/max duration, overlap rules). Each pillar has auto‑place toggle.

⸻

6.4 XP / XXP System

Intent. XP ≈ how well Rethink knows you. XXP ≈ how much work it performed that led to valuable outcomes.

UI: Always visible at top: XP | XXP with level rings and today/7‑day delta.

Sources
	•	XP: confirmed facts (intake answers), stable behaviors (3×+), calendar inference accuracy (scheduled↔backfilled match), clarity of constraints.
	•	XXP: accepted auto‑placements, successful reschedules, gap fills that were completed, goal progress attributed to AI‑proposed chains.

Fairness & Anti‑gaming
	•	Diminishing returns for micro‑actions; cap per day by persona; verify with completion/backfill; penalize churn (approve→undo).

Scoring (first pass)
	•	XP_t = Σ (w_f * confirmed_facts) + Σ (w_b * stable_behaviors) + Σ (w_a * accuracy)
	•	XXP_t = Σ (v_p * accepted_placements * completion) + Σ (v_r * resolved_reschedules) + Σ (v_g * goal‑linked completions)
	•	Global comparability: Normalize by day‑length, meeting load, and baseline entropy of schedule. Publish anonymized percentiles.

⸻

6.5 Goals & Dream Builder
	•	States: Draft / On / Off. Draft contains prep; On feeds suggestions; Off pauses.
	•	Dream Builder mode: shows latent concepts extracted from the user’s conversations/events (“move city”, “ship portfolio”, “marathon”). User can merge concepts to generate goals with starter Chains; purchase with XP/XXP if gated.
	•	Scoring: AI rates goal importance & action quality (transparent rubric). High‑value goals earn bonus XXP on progress.

⸻

6.6 Intake (Periodic Q&A)
	•	“Ask Me” pane: short, targeted questions (e.g., dinner window, commute days, teeth before/after food) with long‑press to reveal “what AI thinks”.
	•	Lightweight cards to confirm/update knowledge with one tap. Surfaces inferred rules for approval.

⸻

6.7 Backfill & Gap Filler
	•	Backfill: Today / Yesterday / Older toggle. Presents a day canvas to drag actuals; AI proposes a reconstruction; user can edit and commit.
	•	Gap Filler: proposes micro‑tasks for dead zones based on pillars, energy, and location.

⸻

6.8 Event Editing, Chains & Routines
	•	Collapsed events show + Chain affordances on both ends.
	•	“Add Chain” → shows 3–5 suggestions (with durations) + “Type your own”. One tap inserts adjacent block.
	•	On an existing chain, expand to reveal definition, duration, AI‑generated detail. Option to edit and re‑save template.

⸻

6.9 Suggestions Rail & Reschedule Queue
	•	Right rail toggles Manual / Suggestions. Tap to place at suggested time or drag onto calendar.
	•	Reschedule list persists with badge count. Items stay until resolved or snoozed.

⸻

6.10 Chips & Time Windows
	•	Define chip windows during onboarding (morning, lunch, wind‑down, plan). Chips appear only inside their windows.
	•	Wind‑down chip offers backfill, reflection, and tomorrow planning.

⸻

6.11 Onboarding
	•	Connect Apple Calendar (read/write scopes explained clearly).
	•	Define chip windows.
	•	Capture initial Pillars and soft rules.
	•	Optional import of typical chains.

⸻

6.12 Undo Everywhere
	•	Global 10‑second undo snackbar after any commit.

⸻

7) Information Architecture & Navigation
	•	Primary nav: Planner (Day+Month) | Mind (Guide) | Goals | Intake.
	•	Global: Action Bar (top), XP/XXP (top right), Suggestions/Reschedule rail (right), Settings (popover).
	•	Menu bar extra: quick microphone toggle, “Add Chain,” “Plan Next Hour,” and “I’m Free for …”.

⸻

8) UX Flows (selected)
	1.	Plan My Morning → user says “plan 9–12 around two meetings” → model proposes chain placements + buffer → inline Yes/No → commit → undo available.
	2.	Backfill Yesterday → AI reconstructs → user drags edits → approve.
	3.	Create Pillar → add “Walk” (20–40m, 4×/wk, no overlap meetings) → auto‑place suggestions in windows.
	4.	Save as Routine → same chain completed 3× in 30 days → prompt appears (debounced).
	5.	Dream Builder → merge concepts “portfolio” + “AI design” → goal “Ship AI UX portfolio by Nov” with starter chain.

⸻

9) Data Model (Schemas, JSON‑ish)

Event

{
  "id": "evt_...",
  "source": "apple_calendar|rethink",
  "title": "",
  "start": "ISO8601",
  "end": "ISO8601",
  "location": "",
  "notes": "",
  "summary_ai": "",
  "neighbors": {"has_prev": true, "has_next": false},
  "auto_placed": true,
  "staged": true,
  "committed": false,
  "chain_id": "chn_...",
  "pillar_tags": ["walk","deep_work"],
  "completion": {"done": true, "backfilled_start": "", "backfilled_end": ""}
}

Chain

{
  "id": "chn_...",
  "name": "Deep Work",
  "blocks": [{"duration_min": 90, "label": "Focus", "buffer_min": 10}],
  "defaults": {"location": "home", "energy": "high"},
  "save_as_routine_eligible": true
}

Pillar

{
  "id": "pil_...",
  "name": "Walk",
  "rules": {"windows": [["07:00","09:00"],["17:00","20:00"]], "freq_per_week": 4, "min_min": 20, "max_min": 40, "overlap": "no_meetings"},
  "auto_place": true
}

Goal

{
  "id": "gol_...",
  "title": "Ship AI portfolio",
  "state": "draft|on|off",
  "score_importance": 0.82,
  "score_action_quality": 0.74,
  "chains": ["chn_..."],
  "xp_gate": 200,
  "xxp_bonus": 1.2
}

XP/XXP

{
  "user_id": "usr_...",
  "xp": {"total": 1420, "last7": 210, "sources": [{"type":"fact_confirm","value":8}]},
  "xxp": {"total": 960, "last7": 180, "sources": [{"type":"placement_completed","value":6}]},
  "normalized_percentiles": {"xp": 0.61, "xxp": 0.58}
}


⸻

10) AI Integration for oos20b
	•	Context strategy: Short prompts + structured tool calls. Retrieve from local memory (facts, pillars, chains, recent days) using vector search keyed by date, pillar, goal.
	•	Confidence modes: confident → auto‑place with 1 best option; uncertain → 3 draggable options.
	•	Calibration: accept rate feedback loops adjust thresholds per user and day‑phase.
	•	Reflection line: generated by a lightweight sentiment/assumption head (or rules) with 2‑second TTL.
	•	Latency target: p95 < 1200ms total for propose‑and‑stage.

Example Tool Contracts

placeEvents({ blocks: ChainBlock[], day: Date, rules: PillarRules[], hardBounds: TimeRange }): PlacementProposal
backfillDay({ date: Date, sources: [Calendar, Location] }): BackfillPlan
scoreGoals({ concepts: string[] }): GoalDraft[]


⸻

11) Privacy, Security, Controls
	•	On‑device first; remote calls opt‑in with clear value disclosure.
	•	Data minimization: only calendar, chains, pillars, goals; no email ingest.
	•	Encryption: at rest (FileVault/Keychain) and in transit. Local vector store encrypted.
	•	Transparency: long‑press any intake card → “what AI thinks” + source.
	•	Memory controls: toggle off categories; purge by timeframe; export.

⸻

12) Performance & Quality Bars
	•	p95 render < 16ms/frame for day scroll; ultra‑smooth drag.
	•	Model proposal time p95 < 1.2s; action chips appear < 500ms after output.
	•	Zero‑crash tolerance for commit path; undo reliability = 100% within window.

⸻

13) Telemetry & Learning Loops
	•	Core: proposal_count, acceptance_rate, undo_rate, backfill_match, chain_save_prompt_shown, routine_adoption.
	•	XP/XXP health: distribution by persona, daily caps hit, anti‑gaming triggers.
	•	Privacy: only aggregated, no content text unless opt‑in.

⸻

14) Release Plan & Milestones

0: Prototype 
	•	Day view + month; Action Bar; basic propose‑and‑stage; manual commit; local only.

1: Chains & Pillars
	•	Chains library; “Save as routine”; Pillar soft rules; auto‑place windows; undo.

2: Backfill & Gap Filler 
	•	Yesterday/Older backfill; micro‑tasks; reschedule queue.

3: Goals & Dream Builder 
	•	Concept surfacing; goal merge; XP/XXP gating; scoring rubric.

4: Insights & Intake
	•	Mind Guide with timeframe selector; Wins/Blockers; periodic Q&A.

⸻

15) Risks & Mitigations
	•	Over‑automation annoyance → strict staging, chip windows, confidence calibration.
	•	Gaming XP/XXP → diminishing returns, completion verification, churn penalties.
	•	Latency drift → on‑device inference; cache; incremental proposals.
	•	Model hallucinations → tool‑only actions; schema‑based outputs; strict validators.
	•	Routine spam → 3× rule + completion gate + cooldown.

⸻

⸻

17) Glossary
	•	Chain: a sequence/block used for planning, type of an event (e.g., Deep Work + Buffer).
	•	Pillar: a soft, recurring need (walk, lunch) with rules.
	•	Backfill: reconstruct what happened to improve the model.
	•	Gap Filler: micro‑tasks for dead zones.
	•	XP: model’s knowledge certainty about you.
	•	XXP: model’s work that led to outcomes.

⸻

18) Appendices

A. XP/XXP Rubric (sample weights)
	•	XP: fact_confirm 3 pts; behavior_stable 2 pts; accuracy_hit 1–5 pts; contradiction −2.
	•	XXP: accepted_placement 2–6 pts (by value); completed_gapfill 1–3; goal_milestone 8–15.
	•	Diminishing return after 5 actions/day of same type.

B. Goal Scoring Rubric
	•	Importance (0–1): relevance to stated values, deadline proximity, external consequences.
	•	Action Quality (0–1): specificity, feasibility, chain coverage, time‑risk balance.

C. Example Prompts (tool‑use style)
	•	“Given these pillars and today’s calendar, propose up to 3 placements between 09:00–12:00 with reasons and confidence. Output JSON schema v1.”

D. State Machines
	•	Goal: Draft → On → Off → (Draft).
	•	Event: Staged → Committed → Completed → Backfilled.
	•	Chain: Suggested → Adopted → Routine‑eligible → Routine.

E. Accessibility & Keyboarding
	•	Full keyboard nav; VoiceOver labels; reduced motion; high‑contrast theme; cmd‑\ = push‑to‑talk; ⌘Z global undo.