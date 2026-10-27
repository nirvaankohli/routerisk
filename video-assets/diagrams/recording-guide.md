# RouteRisk submission video guide

Record the iPhone Simulator or a physical iPhone in portrait orientation. For the moving trip, open **Settings → Presentation → Guided showcase**. The showcase drives the blue arrow along a route and presents a practice crash report without requiring you to travel. Show the switch in the video so judges can tell this sequence is a presentation scenario. The four 1920 × 1080 PNG cards in this folder can appear between app clips for 4–6 seconds each.

## Suggested 80-second cut

| Video time | Screen or action | Voiceover |
| --- | --- | --- |
| 0:00–0:07 | Open RouteRisk and show the MapKit route comparison. | “RouteRisk compares travel time with historical crash exposure before a trip starts.” |
| 0:07–0:12 | Card 01 — How scoring works. | “I designed a scoring model that weights nearby crash records by severity, proximity, and recency.” |
| 0:12–0:20 | Move the Faster ↔ Lower Exposure control and open route details. | “The app shows the tradeoff and labels gaps in historical coverage.” |
| 0:20–0:25 | Card 02 — Route tradeoff. | “A lower-exposure option may take longer. The choice stays with the traveler.” |
| 0:25–0:30 | Open Settings, scroll to **Presentation**, and switch on **Guided showcase**. | “Here is a guided presentation of the navigation flow, so I can demonstrate it without driving.” |
| 0:30–0:39 | Record the blue arrow moving along the route while guidance and remaining distance change. Trim the footage to keep the video short; the arrow travels at a plausible road speed. | “The map follows the car and updates directions as the trip progresses.” |
| 0:39–0:44 | Show **Crash reported ahead** and **Practice report · Reroute around it?**. Tap Yes, or let it select after six seconds. | “A practice crash report appears ahead, and RouteRisk asks whether to reroute.” |
| 0:44–1:00 | Show **Rerouting**, the new detour, and the arrow continuing toward the destination. | “The app switches to an alternate path and keeps guiding the driver.” |
| 1:00–1:06 | Card 03 — Live incident alert. | “In a real trip, the app checks active 511NJ crash reports and looks for a clear alternate route.” |
| 1:06–1:13 | Turn the showcase off in Settings. If using a physical iPhone, show its location status. | “Normal navigation uses the phone's location and live MapKit routes.” |
| 1:13–1:20 | Card 04 — Optional safety backup and parent-contact settings. | “Optional parent updates and an experimental possible-impact check add another layer of support.” |

The practice report appears after roughly half a minute of driving at the route's estimated speed. Trim the driving footage in editing if needed. **End Route** turns the showcase off. To record another take, switch **Guided showcase** off and back on in Settings.

## Accuracy notes for the recording

- The showcase position and crash report are practice content. The road route and detour come from MapKit; the showcase stops with an error if an alternate road route cannot load. Do not describe the practice report as live 511NJ data.
- Normal navigation uses Core Location and live MapKit routing. An iOS simulator supplies its own location; only a physical iPhone can demonstrate actual GPS movement.
- Live 511NJ reports are approximate and may be delayed. RouteRisk changes a live route only when MapKit returns an alternate that clears a reported location.
- The historical exposure score is a weighted formula, not a trained machine-learning model or a prediction that a crash will occur.
- Parent texts and calls require the optional delivery service. The guided showcase does not contact a parent.

## Recording inventory — October 25, 2026

The five raw clips in `~/CAC Recordings/` cover much of the app footage for the two planned recordings:

| Recording | Available footage | Still needed |
| --- | --- | --- |
| 1 — Routes and rerouting | `Directions.mp4` shows route choices and historical-exposure details. `Turn On Settings.mp4` shows the settings screen. `Guided Showcase:Warning.mp4` shows moving guidance, the amber practice crash prompt at about 55 seconds, and the new route at about 59 seconds. | Record the scoring code and the route/scoring diagrams. Add a clear Faster ↔ Lower Exposure control shot if it is not readable after trimming `Directions.mp4`. |
| 2 — Parent updates and possible-crash check | `Start & CRASH.MP4` shows the texts arriving in sequence. `ScreenRecording_10-25-2026 13-53-43_1.MP4` shows the complete three-text thread. `Turn On Settings.mp4` includes parent-contact setup. | Record the possible-impact countdown/cancel screen, the relevant safety code, and the safety diagram. If claiming automatic delivery, capture a real service-triggered text or call; the Messages clips alone do not establish what sent them. |

Trim `Directions.mp4` before its “Waiting for your location” ending. In `Turn On Settings.mp4`, omit the moment when the parent-number field contains only `908` and shows a validation warning. The app-only clips have no audio track, so add narration during editing or record it separately. The existing diagrams are PNG files in this folder and are ready to place in the edit.
