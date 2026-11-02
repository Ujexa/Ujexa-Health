# Stage 01 — Design System & Patient App Shell

## Visual direction
The approved Ujexa Health prototype is the visual baseline. The product has its own identity rather than inheriting a generic studio-wide design system.

- Premium, welcoming health-and-wellness aesthetic.
- Light surfaces, purple-led accents and semantic category colours.
- Expressive metric cards, progress rings, timelines and purposeful illustrations.
- Compact labels and concise supporting copy.
- Progressive disclosure; avoid walls of text and oversized forms.
- Smooth, restrained motion with reduced-motion support.

## Tokens
| Token | Value / intent |
|---|---|
| Ink | `#171B3D` primary text |
| Muted | `#69708E` secondary text |
| Purple | `#7938DB` primary action |
| Purple light | `#F1EAFF` soft accent surface |
| Green | Positive/activity category |
| Blue | Measurements category |
| Orange | Medication / caution category |
| Rose | Symptoms / notes category |
| Surface | `#FFFFFF` |
| Canvas | `#F8F8FD` |
| Radius | 14 / 20 / 26 / 32 px scale |
| Elevation | Soft, low-contrast shadows |

## Navigation
Home · Records · central Add · Insights · Profile.

## Component inventory
Brand mark; top bar; profile avatar; notification control; greeting; overview/progress card; metric tile; feature card; quick-action tile; recent activity row; bottom navigation; bottom sheet; Add Menu tile; field controls; primary/secondary buttons; toast/status feedback.

## Add Menu
Symptoms, Medication, Vitals, Meal, Activity, Sleep, Medical Document, Appointment, Voice Note, Log Checkup.

## Checkup entry flow
Visit type → date/time → clinician/facility → reason → measurements → findings → tests/documents → plan/instructions → follow-up → provenance/review → save. The initial app shell exposes a compact subset of fields and expands in later module work packages.

## Accessibility and interaction
- All controls have accessible names and visible focus.
- Keyboard Escape closes sheets; scrim and close control dismiss.
- Touch targets should be at least 44×44 logical pixels in the mobile implementation.
- Reduced-motion preference disables nonessential transitions.
- Status is conveyed with text/icons as well as colour.
- Inputs have persistent labels and contextual validation.
- Prototype actions must work; unsupported backend functions must be clearly identified as prototype-only.

## Stage 01 acceptance criteria
1. Home layout follows the approved hierarchy and visual language.
2. Bottom navigation switches between all four destinations.
3. Central Add and More open the same Add Menu.
4. Every Add Menu tile opens its corresponding structured entry form.
5. Checkup can be started from both Home quick actions and Add Menu.
6. Form submit gives explicit feedback; prototype does not claim durable storage.
7. Sheets close using close, scrim and Escape.
8. Responsive layout works on narrow and wide viewports.
9. Keyboard interaction and semantic labels are present.
10. No production health data is stored by the prototype.
