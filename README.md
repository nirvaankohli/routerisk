# RouteRisk

RouteRisk is a native iOS navigation demo that compares travel time with **historical crash exposure**. It deliberately uses careful language: an exposure score is a relative estimate based on historical records, not a prediction or a guarantee of safety.

![RouteRisk icon](RouteRisk/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)

## What is included

- SwiftUI, MapKit, Core Location, async/await, MVVM architecture
- Live Apple Maps route alternatives from the New Jersey State House to Princeton University by default
- Public DVRPC historical New Jersey fatal/serious-injury crash records (2017–2021), matched to route segments without an API key
- Clearly labeled offline demo fallback and explicit coverage notices for routes outside the public dataset
- Daytime, evening, and nighttime context, with historical nighttime adjustment
- Faster ↔ Lower Exposure ranking control, explainable route details, map segment overlays, and MapKit destination autocomplete
- Minimal three-screen onboarding, Dynamic Type-friendly native views, VoiceOver labels, light/dark system appearance, and non-color-only exposure labels

## Open and run

1. Open [RouteRisk.xcodeproj](RouteRisk.xcodeproj) in Xcode 16 or newer.
2. Choose an iPhone simulator running iOS 17 or newer.
3. Build and run the `RouteRisk` scheme.
4. Complete the short onboarding. The default route loads from Apple Maps and is scored against DVRPC's public historical crash layer. Use **Settings → Load New Jersey demo** for the offline demonstration.

Location permission is optional. Route search, routing, maps, and the live historical crash layer use the network. The offline demo works entirely from local data.

## Architecture

```
RouteRisk/
  App/                 App entry point and onboarding gate
  Models/              Crash, route, exposure, and travel-mode models
  ViewModels/          UI orchestration and ranking state
  Services/
    CrashData/         DVRPC public-data provider plus local demo provider
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

All weights are in `RiskScoringConfiguration`, not in SwiftUI views. `DVRPCCrashDataProvider` loads nearby public records before scoring; `SampleCrashDataProvider` keeps the explicit demo reproducible and offline.

## Tests

`RouteRiskTests/RiskScoringServiceTests.swift` covers geographic point-to-road distance, severity weighting, nighttime adjustment, and the route-ranking slider behavior. Run them from Xcode with **Product → Test**.

## Data and privacy

RouteRisk queries DVRPC's public regional New Jersey fatal/serious-injury crash layer only for route geometry; it does not upload movement history or require an account. The live layer currently covers the greater Philadelphia region, and its 2017–2021 vintage is displayed in the app. Other destinations show an explicit coverage notice rather than an invented score. The bundled dataset remains clearly marked as **Demo Data**.
