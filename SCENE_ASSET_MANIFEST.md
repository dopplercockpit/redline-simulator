# SCENE_ASSET_MANIFEST.md

## Purpose
Minimal production-planning manifest for Redline scene buildout. This is grounded in current repo reality and intended to guide:
- graphics generation briefs
- hotspot planning
- panel linkage checks
- scene implementation order

This file is documentation only. It does not change runtime behavior.

## Current Runtime Anchor
- Main scene: `res://scenes/WorldMap.tscn` (`project.godot`)
- Active navigation chain: `WorldMap -> Hallway -> CFOOffice`
- Current room art inventory:
  - `res://assets/backgrounds/CFOOffice.png`

## Scene 1: World Map
- `scene_path`: `res://scenes/WorldMap.tscn`
- `status`: `partial`
- `gameplay_purpose`: Top-level entry/navigation and week/month status display.
- `linked_panels`: None directly (scene-level navigation buttons only).
- `required_background_art`:
  - One 16:9 background plate for world/HQ selection (current scene uses flat `ColorRect`).
- `required_hotspot_objects`:
  - `EnterHQ` (active)
  - `Boardroom` (currently locked)
  - `Archives` (currently locked)
  - `Coffee` (currently locked)
- `optional_variant_states`:
  - locked vs unlocked visual states for destinations
  - day/night or scenario-phase tint
- `ai_surfaces_used`: none
- `implementation_priority`: `P1`
- `asset_guidance`:
  - Asset type: background plate + optional icon overlays for destination affordances.
  - Web-demo value: medium (first impression scene).

## Scene 2: Hallway
- `scene_path`: `res://scenes/Hallway.tscn`
- `status`: `partial`
- `gameplay_purpose`: Intermediate HQ navigation into CFO Office and future rooms.
- `linked_panels`: None directly.
- `required_background_art`:
  - One 16:9 hallway/interior plate (current scene uses flat `ColorRect`).
- `required_hotspot_objects`:
  - `EnterCFO` (active)
  - `Boardroom` (currently locked)
  - `Archive` (currently locked)
  - `Coffee` (currently locked)
  - `Back` to World Map (active)
- `optional_variant_states`:
  - unlocked room signage variants
  - subtle progression dressing (e.g., notice board updates)
- `ai_surfaces_used`: none
- `implementation_priority`: `P1`
- `asset_guidance`:
  - Asset type: background plate + door labels/hotspot markers.
  - Web-demo value: medium (navigation continuity).

## Scene 3: CFO Office
- `scene_path`: `res://scenes/CFOOffice.tscn`
- `status`: `existing`
- `gameplay_purpose`: Core interactive room for weekly decisions, panel access, and scenario flow.
- `linked_panels`:
  - `res://ui/FinancialPanel.tscn`
  - `res://scenes/panels/InboxPanel.tscn`
  - Lazy-spawned: `res://ui/NewsPanel.tscn`, `res://ui/CompendiumPanel.tscn`, `res://ui/ContractPanel.tscn`, `res://ui/ScenarioPanel.tscn`
  - `DialogueBox` CanvasLayer for contextual text
- `required_background_art`:
  - Existing: `res://assets/backgrounds/CFOOffice.png`
  - Recommended add-ons: optional hotspot overlay map for authoring/debug, optional variant plates.
- `required_hotspot_objects`:
  - Wired/active:
    - `Hotspot_Laptop` -> Financial Panel
    - `Hotspot_Newspaper` -> News Panel (dynamic `/v1/gen/news`)
    - `Hotspot_Phone` -> Inbox Panel (dynamic `/v1/gen/inbox`)
    - `Hotspot_Bookcase` -> Compendium Panel + Nudge (dynamic `/v1/coach/nudge`)
    - `Hotspot_Cabinet` -> Contract Panel
    - `Hotspot_Door` -> Hallway
  - Present but not currently wired:
    - `Hotspot_Desk`, `Hotspot_Winefridge`, `Hotspot_Window`, `Hotspot_Painting`, `Hotspot_TV`
- `optional_variant_states`:
  - month-end state (documents/screens active)
  - scenario progression dressing (props/desk clutter)
  - lighting variants (day/evening)
- `ai_surfaces_used`:
  - `news`: yes
  - `inbox`: yes
  - `nudge`: yes
- `implementation_priority`: `P0`
- `asset_guidance`:
  - Asset type: hero background plate + optional hotspot hint sprites.
  - Web-demo value: high (main playable value surface).

## Scene 4: Boardroom (Near-Term Planned)
- `scene_path`: `res://scenes/Boardroom.tscn` (planned; not in repo yet)
- `status`: `planned`
- `gameplay_purpose`: Month-end/mission assessment room; host quiz/checkpoint interactions.
- `linked_panels`:
  - Existing overlay to reuse: `res://ui/BoardroomQuiz.tscn`
- `required_background_art`:
  - One 16:9 boardroom plate (table/screen focus).
- `required_hotspot_objects`:
  - start/reopen quiz
  - review monthly packet
  - exit/back
- `optional_variant_states`:
  - pre-close vs post-close state
  - pass/fail feedback dressing
- `ai_surfaces_used`: none required for MVP
- `implementation_priority`: `P1`
- `asset_guidance`:
  - Asset type: background plate + screen/desk hotspot markers.
  - Web-demo value: high (clear learning checkpoint).

## Scene 5: Archive Room (Near-Term Planned)
- `scene_path`: `res://scenes/ArchiveRoom.tscn` (planned; not in repo yet)
- `status`: `planned`
- `gameplay_purpose`: Browse reference materials (contracts, prior reports, scenario artifacts).
- `linked_panels`:
  - likely reuse: `ContractPanel`, `CompendiumPanel`, report-oriented overlays
- `required_background_art`:
  - One 16:9 archive/library plate.
- `required_hotspot_objects`:
  - contract shelf/cabinet
  - reports terminal
  - exit/back
- `optional_variant_states`:
  - unlocked content sections by progression
- `ai_surfaces_used`: optional later, not required for current vertical slice
- `implementation_priority`: `P2`
- `asset_guidance`:
  - Asset type: background plate + shelf/terminal affordance icons.
  - Web-demo value: medium (depth/completeness).

## Scene 6: Coffee / Water Cooler Corner (Near-Term Planned, Low Priority)
- `scene_path`: `res://scenes/CoffeeCorner.tscn` (planned; not in repo yet)
- `status`: `planned`
- `gameplay_purpose`: Optional flavor/social beat and future event delivery surface.
- `linked_panels`:
  - none required for MVP; dialogue-only is sufficient
- `required_background_art`:
  - One small lounge/coffee 16:9 plate.
- `required_hotspot_objects`:
  - interactable coffee machine/cooler
  - exit/back
- `optional_variant_states`:
  - ambient crowd/no-crowd variation
- `ai_surfaces_used`: none required
- `implementation_priority`: `P3`
- `asset_guidance`:
  - Asset type: lightweight background plate + one interaction affordance.
  - Web-demo value: low (polish/atmosphere).

## Build Order Recommendation (Minimal)
1. Polish CFO Office asset pack (P0) because all current dynamic panels and AI surfaces route through it.
2. Replace placeholder visuals for World Map + Hallway (P1) to improve web demo flow continuity.
3. Add Boardroom scene shell (P1) and reuse `BoardroomQuiz` overlay.
4. Add Archive room shell (P2) after boardroom path is stable.

## Notes for Graphics Generation
- Keep all scene plates web-friendly (compressed textures, 16:9 safe framing).
- Preserve clear clickable affordances for known hotspots; do not hide primary interactions in decorative clutter.
- Prioritize readability under UI overlays (Financial/News/Inbox/Compendium/Contract panels).
