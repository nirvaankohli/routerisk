# RouteRisk

RouteRisk is a native iOS navigation demo that compares travel time with **historical crash exposure**. It deliberately uses careful language: an exposure score is a relative estimate based on historical records, not a prediction or a guarantee of safety.

![RouteRisk icon](RouteRisk/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)

## What is included

- SwiftUI, MapKit, Core Location, async/await, MVVM architecture
- Local, reliable Congressional App Challenge demo from the New Jersey State House to Princeton University
- Three offline route alternatives: Fastest, Balanced, and Lower Exposure
- Local crash records matched to route segments using configurable proximity and severity scoring
- Daytime, evening, and nighttime context, with historical nighttime adjustment
- Faster ↔ Lower Exposure ranking control, explainable route details, map segment overlays, and MapKit destination autocomplete
- Minimal three-screen onboarding, Dynamic Type-friendly native views, VoiceOver labels, light/dark system appearance, and non-color-only exposure labels

## Open and run

1. Open [RouteRisk.xcodeproj](RouteRisk.xcodeproj) in Xcode 16 or newer.
2. Choose an iPhone simulator running iOS 17 or newer.
3. Build and run the `RouteRisk` scheme.
4. Complete the short onboarding. The offline demo loads immediately. Use **Settings → Load New Jersey demo** at any time to reset it.

Location permission is optional. The demo works entirely from local data; MapKit search and base-map tiles are the only optional online services.

## Architecture

```
RouteRisk/
  App/                 App entry point and onboarding gate
  Models/              Crash, route, exposure, and travel-mode models
  ViewModels/          UI orchestration and ranking state
  Services/
    CrashData/         Local provider protocol plus future remote boundary
    RiskScoring/       Isolated configurable scoring engine
    Routing/           MapKit directions and autocomplete
    Location/          Permission and one-shot location support
  Utilities/           Geographic distance and segment functions
  DemoData/            Local New Jersey crash records and route fixtures
  Views/, Components/  SwiftUI map-first experience
```

## Scoring model

Each segment finds local crashes within a configured radius. Segment exposure combines crash severity, recency, proximity, speed context, mode-specific factors, and a nighttime multiplier when relevant historical lighting conditions are present.

```
Segment risk = crash frequency × severity × recency × context
Route exposure = weighted sum of segment risk / route length
Route cost = time weight × normalized travel time
           + exposure weight × normalized historical exposure
```

All weights are in `RiskScoringConfiguration`, not in SwiftUI views. `CrashDataProvider` is the seam for a future New Jersey backend. The current `SampleCrashDataProvider` keeps the demo reproducible and offline.

## Tests

`RouteRiskTests/RiskScoringServiceTests.swift` covers geographic point-to-road distance, severity weighting, nighttime adjustment, and the route-ranking slider behavior. Run them from Xcode with **Product → Test**.

## Data and privacy

The bundled dataset is clearly marked as **Demo Data** and is representative rather than authoritative. RouteRisk requires no account and does not store movement history. A real deployment should source validated public crash data, document its methodology, and refresh results responsibly.
