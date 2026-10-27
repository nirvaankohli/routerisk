# RouteRisk Design System

## Design intent

RouteRisk is a precise, map-first decision tool. The primary scene is a driver glancing at an iPhone mounted in a car, in changing daylight, who needs a confident route comparison in a few seconds. The map stays familiar; the app's panels provide the calm analytical layer.

## Color system

- Ink: `#131313` (neutral dark gray)
- Surface: `#292929` (neutral dark gray for both route panels)
- Elevated surface: `#363636`
- Blue: `#0A84FF` (primary selection and action)
- Teal: `#1B9D88` (lower historical exposure)
- Amber: `#D88A16` (elevated historical exposure)
- Red: `#C94A4A` (highest relative exposure only)
- Alternative route: `#ABC2FF` (lighter than selected blue)

Use semantic exposure labels and icons alongside every color. Blue is reserved for selected routes, direct action, and focus; exposure green remains a separate data color. The chosen route remains blue on the map, with narrower amber and red marks where historical exposure is elevated.

## Typography

Use SF Pro through SwiftUI's system typography. Strong hierarchy comes from weight and modest size steps: large rounded title, semibold route minutes, compact all-caps metadata. Use monospaced digits for route metrics where alignment matters.

## Surfaces and components

Use solid neutral surfaces for the route header and bottom sheet. Directions use a single list with subtle separators and a slightly lighter selected row. Travel modes sit in a connected icon-only pill selector with accessibility labels. Use 16–22 pt corners, 44 pt minimum hit areas, concise labels, Material Icons for navigation controls, and 150–250 ms state transitions.

## Layout

The map owns the screen. The two-endpoint route panel stays fixed at the top while a draggable route sheet rises from the bottom. Route options sit in the sheet. Detail is progressive, reached through the selected route's explanation.

Each option has a solid mint GO button with green dominant over cyan. Starting a route replaces the comparison sheet with compact in-app guidance, keeps the selected path visible, and follows the user's location while it is on the route. The route name itself carries its category, so the row does not repeat it in a badge or an explanatory sentence.
