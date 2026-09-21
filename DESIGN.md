# RouteRisk Design System

## Design intent

RouteRisk is a precise, map-first decision tool. The primary scene is a driver glancing at an iPhone mounted in a car, in changing daylight, who needs a confident route comparison in a few seconds. The map stays familiar; the app's panels provide the calm analytical layer.

## Color system

- Ink: `#091629` (deep blue-black, never pure black)
- Navy: `#102847`
- Blue: `#147BF3` (primary selection and action)
- Teal: `#1B9D88` (lower historical exposure)
- Amber: `#D88A16` (elevated historical exposure)
- Red: `#C94A4A` (highest relative exposure only)
- Canvas light: `#F6F8FC`
- Canvas dark: `#0B1422`

Use semantic exposure labels and icons alongside every color. Accent blue is reserved for selected routes, direct action, and focus.

## Typography

Use SF Pro through SwiftUI's system typography. Strong hierarchy comes from weight and modest size steps: large rounded title, semibold route minutes, compact all-caps metadata. Use monospaced digits for route metrics where alignment matters.

## Surfaces and components

Use native materials sparingly for floating map controls. Route options are broad, low-elevation panels with a selected outline rather than decorative accent stripes. Use 16–22 pt corners, 44 pt minimum hit areas, concise labels, SF Symbols, and 150–250 ms state transitions.

## Layout

The map owns the screen. A compact search dock floats at the top; a draggable route sheet rises from the bottom. Route cards form a horizontal decision rail rather than a generic grid. Detail is progressive, reached through the selected route's explanation.
