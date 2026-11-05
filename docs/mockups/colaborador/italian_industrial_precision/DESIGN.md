---
name: Italian Industrial Precision
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#5c403d'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f1f1f1'
  outline: '#906f6c'
  outline-variant: '#e5bdba'
  surface-tint: '#bd0f20'
  primary: '#b3011a'
  on-primary: '#ffffff'
  primary-container: '#d7282f'
  on-primary-container: '#fff2f1'
  inverse-primary: '#ffb3ad'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e5e2e1'
  on-secondary-container: '#656464'
  tertiary: '#575858'
  on-tertiary: '#ffffff'
  tertiary-container: '#707070'
  on-tertiary-container: '#f6f5f5'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad7'
  primary-fixed-dim: '#ffb3ad'
  on-primary-fixed: '#410004'
  on-primary-fixed-variant: '#930013'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1c1b1b'
  on-secondary-fixed-variant: '#474646'
  tertiary-fixed: '#e3e2e2'
  tertiary-fixed-dim: '#c7c6c6'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#464747'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  headline-xl:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.03em
  caption:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 12px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-sm: 0.75rem
  margin: 1rem
  margin-lg: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system establishes a high-performance, mobile-first utility for on-site technicians, facility managers, and staff across Chilean facilities. Reflecting the heritage of professional salon engineering, the interface balances industrial utility with Italian luxury minimalism. 

Key attributes:
- **Tone:** Authoritative, disciplined, refined, and hyper-legible under harsh indoor/outdoor maintenance lighting.
- **Visual Aesthetic:** Minimalist Corporate Modernism. Structural clarity replaces decorative excess. Form follows precision through calibrated whitespaces, hairline structural dividers, and deliberate high-contrast touch interactions.
- **Emotional Resonance:** Trust, efficiency, and professional pride. The interface feels less like an administrative back-office chore and more like an ergonomic, calibrated digital tool.

## Colors

The palette operates under rigorous chromatic discipline. Red is never applied gratuitously; it functions as an operational signal and anchor for critical paths.

- **Primary Brand Red (`#D7282F`):** Strictly reserved for primary key interactive CTAs, focused input states, and negative terminal states (`Rechazado` / `Error`). Restricting red ensures instant visual priority.
- **Near-Black (`#111111`):** Applied to primary typography, selected tab bars, prominent containers, and high-priority monochrome chips. Delivers crisp legibility without the harshness of `#000000`.
- **Pure White (`#FFFFFF`):** Base canvas background for elevate cards, actionable surfaces, sheets, and modal views.
- **Surface Light Gray (`#F4F4F4`):** Canvas background foundation, inset panels, deactivated states, and neutral status fills.
- **Border Gray (`#E5E5E5`):** Structural hairline dividers, unselected tab outlines, and card perimeters.
- **Text Secondary (`#8A8A8A`):** Metadata, timestamps, helper labels, supporting descriptions, and inactive states.

### Status Badge Strategy
To eliminate visual cognitive fatigue caused by multicolor "traffic lights," operational statuses rely on a calibrated monochrome taxonomy:
- **Pendiente / En Espera:** Surface `#F4F4F4`, Text `#111111`, Border `#E5E5E5`.
- **En Progreso / Asignado:** Surface `#111111`, Text `#FFFFFF`, Border `#111111`.
- **Resuelto / Completado:** Surface `#FFFFFF`, Text `#111111`, Border `#111111` (accentuated by a crisp check icon).
- **Rechazado / Crítico:** Surface `#FFF1F1`, Text `#D7282F`, Border `#D7282F` (the sole permitted chromatic departure).

## Typography

The design system utilizes **Inter** across all typographic hierarchies to ensure technical clarity, uniform vertical metrics, and optical legibility on mobile screens under high sunlight or dim technical rooms.

- **Headlines:** Dense and authoritative with slightly tightened tracking (`-0.02em` to `-0.01em`) to maintain an engineered, architectural posture.
- **Body:** Open line-heights calibrated for rapid scanning of operational tickets, technical reports, and catalog specifications.
- **Labels & Badges:** Slightly wider tracking and increased weights (`600`) to guarantee contrast against solid and stroked micro-surfaces.
- **Language Adaptations (es-CL):** Designed to support variable Spanish sentence lengths gracefully without breaking card boundaries or overflowing fixed height constraints.

## Layout & Spacing

A strictly regulated 4-column fluid mobile grid forms the foundation of the viewport, bound by strict adherence to device boundaries:

- **Canvas & Viewport:** Standard mobile screens feature `margin: 1rem` (16px) left and right padding, expanding to `1.25rem` (20px) on larger handheld form factors.
- **Safe Area Insets:** Top safe area accommodates dynamic device notches. Bottom safe area reserves baseline padding (minimum 34px on gesture-based iOS devices) underneath the fixed bottom navigation bar to avoid navigation collisions.
- **Touch Target Integrity:** Every tappable node maintains a strict minimum bounding box of 48×48px, preventing misclicks during field inspections.
- **Vertical Rhythm:** Elements group according to standard multiples of 4px and 8px: 4px (`space-xs`) for icon/text groupings, 8px (`space-sm`) for label-to-field distances, 16px (`space-md`) for container interiors, and 24px (`space-lg`) for card section stacks.

## Elevation & Depth

To sustain a crisp, high-end Italian aesthetic and prevent visual muddiness, this system eliminates blurred drop shadows entirely in favor of **Tonal Layers and Structural Hairline Boundaries**:

- **Level 0 (Canvas Base):** Background substrate colored `#F4F4F4`.
- **Level 1 (Resting Cards & Panels):** Solid `#FFFFFF` fill bounded by a continuous 1px `#E5E5E5` perimeter border. No ambient blur.
- **Level 2 (Active Modals & Bottom Sheets):** Solid `#FFFFFF` fill resting on top of a 30% alpha `#111111` overlay scrim. The sheet surface features a top structural hairline of 1px `#E5E5E5`.
- **Level 3 (Sticky Controls & Bottom Navigation):** Solid `#FFFFFF` surface with an upper boundary defined by a sharp 1px `#E5E5E5` hairline edge.

## Shapes

The geometry strikes a calculated equilibrium between ergonomic comfort and industrial precision:

- **Cards & Primary Modules:** Uniform border radius of 16px (`rounded-lg` token tier), providing a modern, tactile silhouette for equipment blocks and incident records.
- **Interactive Controls (Inputs, Standard Buttons):** 8px to 12px border radius, balancing tactile friendliness without losing structural rigidity.
- **Badges, Chips & Pills:** Full pill radius (9999px) for operational statuses, reinforcing their role as distinct categorized data objects.
- **Interactive Floating Points / Small Checkboxes:** Precise 4px radius for selective controls, retaining crisp geometric corners.

## Components

### Buttons
- **Primary:** Background `#D7282F`, text `#FFFFFF`, height 48px, radius 8px, font `label-lg`. Pressed state: `#B81D23`.
- **Secondary:** Background `#111111`, text `#FFFFFF`, height 48px, radius 8px. Pressed state: `#2A2A2A`.
- **Outlined / Tertiary:** Background transparent, border 1px `#E5E5E5`, text `#111111`, height 48px, radius 8px.

### Cards
- Surface `#FFFFFF`, border 1px `#E5E5E5`, border radius 16px, padding 16px (`space-md`). Internal metadata sections are separated by 1px `#F4F4F4` dividers.

### Chips & Status Badges
- Height 24px, radius 9999px, horizontal padding 8px, font `label-sm`.
- Accompanied by a 12px line-weight technical icon aligned to the left of the text label.
- Color combinations strictly adhere to the monochrome logic outlined in Section 2.

### Input Fields
- Height 48px, background `#FFFFFF`, border 1px `#E5E5E5`, border radius 8px, horizontal padding 12px.
- **Focused State:** 1.5px border `#D7282F` with no external glow.
- **Error State:** 1.5px border `#D7282F` accompanied by a `#D7282F` caption text underneath.
- **Placeholder:** `#8A8A8A`, font `body-md`.

### Checkboxes & Radios
- Size 20×20px, minimum touch area 48×48px. Border 1.5px `#8A8A8A`.
- Active state fills with `#111111` featuring a crisp `#FFFFFF` icon.

### Bottom Navigation Bar
- Fixed bottom container adhering to mobile bottom safe areas. Total height: 56px + safe-area-inset-bottom.
- Background `#FFFFFF`, top border 1px `#E5E5E5`.
- 4 Fixed Tabs:
  1. **Inicio**
  2. **Catálogo**
  3. **Reportar falla**
  4. **Mis solicitudes**
- **Active Tab:** Icon and label in `#111111` with a micro-indicator dot in `#D7282F` positioned centrally below the label.
- **Inactive Tab:** Icon and label in `#8A8A8A`.

### Maintenance Request Items (List Row)
- Bounded card or bottom-divided row featuring: Incident ID (`label-md`, `#8A8A8A`), Issue Title (`headline-sm`, `#111111`), Location/Area tag (`body-sm`, `#8A8A8A`), and right-aligned Monochrome Status Badge.