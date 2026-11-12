# Hush Hour (NellSays)

First-person co-op horror for 1–4 players, built from `Hush-Hour-GDD.docx` (the source of truth).
Repo: https://github.com/RedFishStudios/NellSays. The Studio place is `../Place1.rbxl` (git-ignored).

## Layout (Lync project: `default.project.json`, port 34874)
- `src/shared` → `ReplicatedStorage.Shared`: `Config` (all GDD tuning), `Net` (one multiplexed RemoteEvent + unreliable look channel), `Sounds` (verified audio IDs).
- `src/server` → `ServerScriptService.Server`: `Main` (entry), `State` (replicated attributes, pausable stage `Clock`, `Fx` bus), `Roster`, `Lobby`, `Director` (chapter flow, Full/Quick), `Cues` (Simon Says grading), `Stations` (missions + challenge validation), `Hiding`, `Puppeteer`, `Death` (shared cutscene + TV puppets), `Lights`, `Props`, `Build/` (house, studio set, Nell and Puppeteer built from code at server start).
- `src/client` → `StarterPlayerScripts.Client`: `Main`, `Hud`, `LobbyUi`, `Minigames`, `Cinema` (camera owner: cutscenes > hide peek > spectate), `Tv` (CRT + HUD viewport mirror of Nell's stage), `Audio` (sfx, loops, TTS voices), `Controls`, `TestPanel` (Studio only).

## Rules
- Server owns round state, timers, missions, strikes, hiding, sight, deaths and votes. Clients only render and send inputs.
- Game state replicates as attributes on `ReplicatedStorage.GameState` (+ `Stations`, `Slots` folders) and on `Player` objects.
- Use `Clock.wait` (stage time) for anything that must pause during death cutscenes.
- Every audio cue needs a caption/HUD equivalent (muted play must work).
- Voices: `AudioTextToSpeech`. Roblox's text filter blocks some lines (e.g. anything about parents being away); pass `voiceText` to `Fx.say` with a safe spoken variant and keep the caption.
- ProximityPrompts only show when on screen; face the object when testing.

## Toolchain (Rokit, `rokit.toml`)
- `rokit install`, then `lync serve` and press Sync in the Lync widget (set port 34874; BoomerangUI uses 34873).
- AI sessions without Lync: run `node tools/sync.js`, then execute `tools/pull.luau` in Studio edit mode via the Studio MCP `execute_luau`.
- `stylua src` and `selene src` before committing (0 selene errors expected).

## Testing
See `docs/TESTING.md`. Studio test panel: TEST button (top right) or F2.
