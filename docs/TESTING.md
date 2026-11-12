# Testing Hush Hour in Studio

Open `C:\Users\zoeyf\Desktop\Hush Hour\Place1.rbxl`. Scripts live in ServerScriptService.Server, ReplicatedStorage.Shared and StarterPlayer.StarterPlayerScripts.Client. The house is rebuilt from code every time the server starts.

## Controls
- Keyboard: WASD move, mouse look, Shift sprint (5 s stamina), C crouch toggle, E interact / hide / leave hiding / station input, Q ping, 1–4 for symbol buttons, A/D on dials.
- Controller: left stick, L3 sprint, B crouch, X interact, D-pad up ping.
- Mobile: on-screen Sprint / Crouch / Ping buttons; tap prompts and HUD buttons.
- HUD ping buttons: On my way, I have this, Help, Hide, Monster, Ready.
- Studio test panel: TEST button (top right) or F2.

## Solo
1. Test tab → Play (F5).
2. Lobby: click Claim on a Player card, pick a challenge, click 2. QUICK TEST (or 1. FULL EPISODE), click READY. The run starts after a 3-second countdown.
3. Intro: watch it, or click Vote to skip (it unlocks after 8 s; solo = unanimous).
4. Obey only lines that start with "Nell says". Each order shows a caption card with the source badge, a hint and a response-window bar.
5. Sound Check: the roster lists your station jobs, and a yellow marker floats over each one. Stand in the zone, face the station, press E, and finish the challenge. Reel/Reset Timing = press E when the white marker is inside the green band, 3 times. Stay in the zone until the lock bar fills.
6. HIDE: when Nell screams, press E at a couch end, the dining bench, the kid's desk, the bedroom closet or the bath tub. Move the mouse to peek. Press E or click Leave to come out.
7. Last Broadcast: vote Stay for Sign-Off (The Audience) or Pull the Disc (Off Air: deck, Gear symbol, relay, hold Eject then Break Disc, then escape through a gate after 40 s or 44 s).
8. Results show each player's outcome. Click ▶ REPLAY.

## Four clients
1. Test tab → Clients and Servers → Local Server, set Players to 4 → Start. Four client windows and one server window open.
2. In each client: claim a different Player number, pick a challenge, click READY. Pick the mode in one client first.
3. Sound Check: each client goes to its own station. Use the server window or a client's TEST panel to Eliminate one player mid-wave, and check that their unfinished job moves to a living player in the roster while done jobs keep ✓.
4. Every client, including spectators, should see the death scene once and the same puppet beside Nell on the den CRT. A dead client gets ◀ ▶ / TV stage spectator controls.
5. HIDE: hide two clients and leave one in the open; the exposed one is spotted, chased and caught (shared death).
6. Finish or Restart session, click REPLAY, and confirm strikes, slots, stations and TV puppets reset.

## Test panel (Studio only)
Jump to chapter 1–7 · cycle the selected player · +1 Strike · Eliminate · Start HIDE patrol · Force start · Restart session. It also shows phase, mode, chapter, timer, living players, strikes, puppets and station owners.
