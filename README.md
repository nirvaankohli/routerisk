# RouteRisk

RouteRisk is a native iOS navigation app that compares travel time with **historical crash exposure**. An exposure score is a relative estimate based on historical records, not a prediction or a guarantee of safety.

![RouteRisk icon](RouteRisk/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)

## What is included

- SwiftUI, MapKit, Core Location, async/await, MVVM architecture
- Live MapKit route alternatives from the New Jersey State House to Princeton University by default
- Public DVRPC historical New Jersey fatal/serious-injury crash records (2017–2021), matched to route segments without an API key
- Live MapKit traffic display and explicit coverage notices for routes outside the public crash dataset
- Live 511NJ crash markers near the active route, plus a separate guided showcase for recording a moving trip and practice reroute
- Faster ↔ Lower Exposure ranking control, explainable route details, map segment overlays, and MapKit destination autocomplete
- A GO button on each route that starts in-app visual guidance with the selected route, live map following, current and following maneuvers, remaining time, ETA, and distance
- In-trip **Reroute** from the current location and **Add stop** for a two-leg route through a searched place
- Optional parent trip updates and an experimental possible-crash check during active, foreground route following
- Active 511NJ crash-report checks during foreground route following, with a spoken warning, haptic cue, temporary amber warning, and automatic alternate-route search
- Minimal three-screen onboarding, Dynamic Type-friendly native views, VoiceOver labels, a dark map-first interface, and non-color-only exposure labels

## Open and run

1. Open [RouteRisk.xcodeproj](RouteRisk.xcodeproj) in Xcode 16 or newer.
2. Choose an iPhone simulator running iOS 17 or newer.
3. Build and run the `RouteRisk` scheme.
4. Complete the short onboarding. The default route loads through MapKit and is scored against DVRPC's public historical crash layer. Choose a destination to calculate another live route. For a hands-free recording, open **Settings → Presentation → Guided showcase**.

Location permission is optional for route comparison and needed for live route following. RouteRisk requests the iPhone's location on launch and, when a fix is available, uses it as the default origin. You can also tap the starting point and choose **Use my current location**. Use a physical iPhone to demonstrate actual GPS; simulator locations are supplied by the simulator. Route search, routing, maps, traffic, and the live historical crash layer use the network. Normal route requests show an error if the live service fails; they do not substitute sample routes. Reroute and Add stop need a location fix and network routing. The guided showcase animates an app-controlled position on a MapKit route when available, introduces a practice crash report, and shows a prepared detour. It uses an offline route fixture only if MapKit cannot load the presentation trip, and it does not contact a parent or read that practice report from 511NJ.

## Active crash reports

While a trip is active and RouteRisk is open, the app checks [511NJ's active incident RSS feed](https://www.511nj.org/RSS511Service/RSS511Service.svc/rest/rss/RSSActiveIncidents) about once a minute. It filters for crash reports and shows relevant reports with native MapKit markers when they are near the selected route, roughly 0.1–5 miles ahead of the current location. The warning briefly replaces the top guidance card in amber and uses a spoken message and haptic cue. RouteRisk asks MapKit for alternatives from the current location and switches only if a returned route stays more than 300 meters from the reported crash locations. If none does, it keeps the current route and displays a caution message.

511NJ report positions are approximate and reports may be delayed or incomplete. The feature does not run after the app is suspended and does not imply that an unreported road is clear. MapKit may return no alternate route that clears a reported location, especially when a trip includes a stop. A feed error is shown as unavailable.

## Parent updates and possible-crash alerts

In **Settings**, enter a parent's phone number and enable trip updates or the possible-crash check. A trip update starts when the user taps **GO** and another starts when the app detects arrival near the selected route's destination. The check looks for a strong phone impact while moving at driving speed followed by a sudden GPS speed drop. It gives the user 20 seconds to cancel before contacting the parent.

The departure text says the child started a route and includes the selected route's estimated arrival time. The arrival text includes the time arrival was detected. The possible-crash text asks the parent to check on the child and says the crash is unconfirmed. These times come from the iPhone's local clock; they are not fixed demo values.

Automatic delivery needs the companion Node service in [`server/safety-server.mjs`](server/safety-server.mjs), running on an HTTPS endpoint reachable by the iPhone. The service calls Twilio's real Messages and Calls APIs. Twilio credentials stay on the server. To configure it:

1. Copy [`server/.env.example`](server/.env.example) to `server/.env` and fill in the Twilio account SID, API key SID and secret (or auth token), a Twilio phone number capable of SMS and voice, the parent's phone number, and a long random pairing token. The parent number entered in the app must match `PARENT_PHONE` on the server.
2. Run `node --env-file=server/.env server/safety-server.mjs` with Node 20.6 or newer. The default bind address is `127.0.0.1:8787`; use an HTTPS reverse proxy and suitable `HOST` when deploying to a server.
3. In the iPhone app's **Settings → Automatic delivery service**, enter the HTTPS service URL and the same pairing token as the access code. Tap **Check connection**. This verifies server configuration and the access code; it cannot guarantee Twilio will accept or deliver a later message. A local iOS simulator may use `http://127.0.0.1:8787` for development.

If the service is unavailable, RouteRisk opens a prepared text in Messages for trip updates; the user must tap **Send**. On a simulator without Messages, the app shows a copyable preview. For a possible crash, the fallback opens the iOS phone call prompt; the user must confirm the call. The Twilio service queues an SMS and outbound voice call when configured, but a Twilio trial account may require the parent's number to be verified. Run `node --test server/safety-server.test.mjs` to exercise the service with a test-only Twilio transport.

The motion check is an experimental heuristic, not a validated crash detector or emergency response system. It runs only while RouteRisk is open, active, and following a route. It may miss crashes or react to a non-crash jolt. Its alert says *possible crash* and uses a different iOS notification haptic from the ahead-of-route report. The iPhone must have motion and location data available.

## Architecture

```
RouteRisk/
  App/                 App entry point and onboarding gate
  Models/              Crash, route, exposure, and travel-mode models
  ViewModels/          UI orchestration and ranking state
  Services/
    CrashData/         DVRPC public-data provider and test fixtures
    RiskScoring/       Isolated configurable scoring engine
    Routing/           MapKit directions and autocomplete
    Location/          Permission, one-shot lookup, and foreground route following
    Safety/            Parent messaging, server client, and possible-impact heuristic
  Utilities/           Geographic distance and segment functions
  DemoData/            Route fixtures for offline presentation fallback and unit tests
  Views/, Components/  SwiftUI map-first experience
```

## Scoring model

Each segment finds local crashes within a configured radius. Segment exposure combines crash severity and proximity. The sample dataset also demonstrates mode and nighttime adjustments. The live DVRPC layer does not include observed speed limits or lighting conditions, so those adjustments are not applied to live records.

```
Segment risk = crash frequency × severity × recency × context
Route exposure = weighted sum of segment risk / route length
Route cost = time weight × normalized travel time
           + exposure weight × normalized historical exposure
```

All weights are in `RiskScoringConfiguration`, not in SwiftUI views. `DVRPCCrashDataProvider` loads nearby public records before scoring; `SampleCrashDataProvider` supplies test fixtures only.

## Tests

`RouteRiskTests/RiskScoringServiceTests.swift` covers geographic point-to-road distance, severity weighting, nighttime adjustment, the route-ranking slider, phone validation, and impact gating. Run them from Xcode with **Product → Test**. The Node tests cover authorization, recipient restrictions, SMS and call requests, and duplicate request IDs.

## Data and privacy

RouteRisk queries DVRPC's public regional New Jersey fatal/serious-injury crash layer for route geometry. Parent updates are optional. When enabled with the delivery service, each event sends its destination, current coordinates when available, event type, and parent number to the configured server and Twilio. The service accepts only the parent number set in its environment. It does not store trip history. RouteRisk requires no account. The historical crash layer currently covers the greater Philadelphia region, and its 2017–2021 vintage is displayed in the app. Other destinations show an explicit coverage notice rather than an invented score. Bundled sample crash records are used by tests, while the guided showcase may use an offline route fixture if MapKit routing is unavailable.
