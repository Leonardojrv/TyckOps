---
name: GAMA Professional Field Ops
colors:
  surface: '#faf9f9'
  surface-dim: '#dbdad9'
  surface-bright: '#faf9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f3f3'
  surface-container: '#efeded'
  surface-container-high: '#e9e8e8'
  surface-container-highest: '#e3e2e2'
  on-surface: '#1b1c1c'
  on-surface-variant: '#5c403d'
  inverse-surface: '#303031'
  inverse-on-surface: '#f2f0f0'
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
  tertiary: '#705300'
  on-tertiary: '#ffffff'
  tertiary-container: '#8e6a00'
  on-tertiary-container: '#fff3e1'
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
  tertiary-fixed: '#ffdf9d'
  tertiary-fixed-dim: '#f9bd14'
  on-tertiary-fixed: '#251a00'
  on-tertiary-fixed-variant: '#5b4300'
  background: '#faf9f9'
  on-background: '#1b1c1c'
  surface-variant: '#e3e2e2'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
    letterSpacing: -0.02em
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
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 20px
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
    fontWeight: '700'
    lineHeight: 14px
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
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

The design system embodies the high-performance engineering, precision, and Italian industrial heritage of GA.MA Italy Professional, calibrated specifically for operations and facility administration. Designed for bilingual Spanish (Chile) administrative teams managing facility maintenance, spare parts, and logistics, the interface communicates absolute precision, immediate urgency triage, and executive clarity.

The visual style blends **Modern Corporate Italian Minimalism** with **Industrial Utility**:
- High-contrast structural boundaries with deliberate negative space, avoiding ornamental fluff.
- Uncompromising visual hierarchy tailored for swift triage under direct sunlight or warehouse lighting.
- Strict operational reliability inspired by professional salon hardware: sleek, tactile, functional, and durable.
- Restrained elegance where brand power is derived from decisive color accents against stark monochromatic planes.

## Colors

The palette balances authoritative black and clinical whites with GA.MA's signature dynamic red. Functional state management relies on clear contrast ratios meeting WCAG 2.1 AA standards across mobile environments.

### Core Swatches
- **Primary Red (`#D7282F`):** Used strictly for high-value interactive states, urgent tickets, primary CTAs, and active bottom navigation indicators.
- **Near Black / Onyx (`#111111`):** Applied to app bars, navigation headers, primary labels, and dark container blocks.
- **Pure White (`#FFFFFF`):** Base canvas background and elevated surface cards.
- **Light Surface Gray (`#F4F4F4`):** Input fields, disabled surfaces, secondary badge fills, and segmented controls.
- **Medium Gray (`#8A8A8A`):** Metadata, timestamps, non-active icon fills, and assistive captions.
- **Warning Yellow (`#F2B705`):** Reserved for inventory stock thresholds, supply warnings, and preventive maintenance triggers.
- **Border / Stroke (`#E5E5E5`):** Structural perimeter lines separating data rows and defining card wrappers.

### Status Semantic Colors
- **Recibido (Neutral Teal/Gray):** Background `#F0F4F8`, Text `#334E68`
- **En revisión (Info Indigo):** Background `#EEF2FF`, Text `#3730A3`
- **Aprobado (Success Emerald):** Background `#ECFDF5`, Text `#065F46`
- **Rechazado (Destructive Red):** Background `#FEF2F2`, Text `#991B1B`
- **En proceso (Operational Blue):** Background `#EFF6FF`, Text `#1E40AF`
- **Resuelto (Finished Teal):** Background `#F0FDFA`, Text `#115E59`
- **Cerrado (Muted Slate):** Background `#F1F5F9`, Text `#475569`
- **Cancelado (Inactive Gray):** Background `#F4F4F4`, Text `#71717A`

## Typography

Typography relies entirely on **Inter** to maximize data legibility and administrative scanning speed. With dense tracking and tabular figures enabled for numbers and ticket counters (`font-variant-numeric: tabular-nums`), the hierarchy establishes clear operational priority.

- **Headings:** Set tightly in Bold (`700`) and Semi-Bold (`600`) with negative tracking for punchy, compact mobile headers.
- **Body:** Regular (`400`) weight configured with comfortable vertical leading to maintain scanning speed across descriptive incident reports.
- **Labels & Chips:** Semi-Bold (`600`) and Bold (`700`) in sentence or uppercase form to indicate interactive roles and status values.
- **Chilean Spanish Localization:** Accented characters (`á`, `é`, `í`, `ó`, `ú`, `ñ`) must respect the standard font line-height bounding boxes without clipping in badges or text inputs.

## Layout & Spacing

The layout is built around a fluid, touch-optimized mobile column system structured strictly on an 8pt architectural rhythm, with a 4pt sub-grid for badges, borders, and micro-alignments.

### Layout Mechanics
- **Grid Layout:** 4-column layout on iOS and Android viewports (up to 480dp width), extending to 8 columns on folding devices and smaller tablets.
- **Margins & Gutters:** Safe margin of 16px (`margin: 1rem`) on outer screen edges; 16px (`gutter: 1rem`) grid gap between internal parallel elements.
- **Safe Area Insets:** Fixed accounting for iOS Dynamic Island/Home Indicator and Android gesture bars. Scroll views apply dynamic bottom padding (`calc(env(safe-area-inset-bottom) + 64px)`) to keep cards from disappearing behind the sticky navigation bar.
- **Touch Ergonomics:** All primary interactive elements adhere strictly to a **48px minimum touch target** dimension, centered with touch slops where visible sizing is smaller.

## Elevation & Depth

To sustain a crisp corporate aesthetic suitable for industrial management, this design system avoids deep, decorative shadows. Depth is achieved via **tonal layering combined with low-contrast structural outlines**.

- **Level 0 (Flat / Canvas):** Surface background `#FFFFFF` or `#F4F4F4`. No outline, no shadow.
- **Level 1 (Card / Resting Surface):** `#FFFFFF` background bound by a crisp 1px stroke of `#E5E5E5`. Ambient shadow: `0px 1px 3px rgba(17, 17, 17, 0.05)`.
- **Level 2 (Active Card / Elevated Filter):** `#FFFFFF` surface with an ambient drop: `0px 4px 12px rgba(17, 17, 17, 0.08)`, border changes to `#D7282F` if actively selected.
- **Level 3 (Sticky Bottom Bar / Floating Modals):** Background `#FFFFFF` with top edge border `1px solid #E5E5E5` and soft elevation `0px -4px 16px rgba(17, 17, 17, 0.06)`.
- **Level 4 (Top Header App Bar):** Background `#111111` with full opacity, providing an anchoring header plane without blur or shadow interference.

## Shapes

The design system employs a disciplined **16px base radius** (`rounded-lg` / `roundedness: 2`) for major structural envelopes, creating approachable yet precise containers.

- **Cards & Data Modules:** 16px corner radius (`rounded-lg`) balances industrial structure with modern mobile ergonomics.
- **Action Buttons & Form Controls:** 12px to 16px radius, matching the parent card cadence.
- **Chips & Status Badges:** Fully rounded pill format (`9999px`) to immediately distinguish contextual metadata from interactive square-ish buttons.
- **Dividers & Lines:** Flat 1px square strokes; no rounded terminal caps on technical data dividers.

## Components

### Buttons
- **Primary CTA:** Height 48px, background `#D7282F`, text `#FFFFFF`, font `label-lg`, radius 12px. Pressed state: `#B51F25`.
- **Secondary Action:** Height 48px, background `#111111`, text `#FFFFFF`, radius 12px.
- **Outline Action:** Height 48px, background transparent, border `1px solid #E5E5E5`, text `#111111`, radius 12px.
- **Touch Target:** Mandatory 48x48px hit area minimum.

### Ticket Status Chips
- Height 26px, corner radius 9999px (pill), horizontal padding 10px. Text style `label-sm`.
- Displays localized Chilean Spanish states:
  - *Recibido:* Surface `#F0F4F8`, text `#334E68`
  - *En revisión:* Surface `#EEF2FF`, text `#3730A3`
  - *Aprobado:* Surface `#ECFDF5`, text `#065F46`
  - *Rechazado:* Surface `#FEF2F2`, text `#991B1B`
  - *En proceso:* Surface `#EFF6FF`, text `#1E40AF`
  - *Resuelto:* Surface `#F0FDFA`, text `#115E59`
  - *Cerrado:* Surface `#F1F5F9`, text `#475569`
  - *Cancelado:* Surface `#F4F4F4`, text `#71717A`

### Input Fields & Search
- Container height 48px, background `#F4F4F4`, border `1px solid #E5E5E5`, radius 12px, text `#111111`, placeholder `#8A8A8A`.
- Active focus state: Background `#FFFFFF`, border `1.5px solid #D7282F`. Includes clear icon (20px) on the trailing end.

### Cards (Tickets & Maintenance Rows)
- Background `#FFFFFF`, 16px radius, padding 16px, border `1px solid #E5E5E5`.
- Contains: Ticket ID (`label-md`, `#8A8A8A`), Title (`headline-sm`, `#111111`), Status Chip (top right), Location/Branch tag, and Timestamp (`body-sm`).

### Inventory Stock Alert Cards
- Same structural base as cards, but items below critical threshold display a 3px vertical accent stripe on the left edge in Warning Yellow (`#F2B705`) along with a "Bajo Stock" badge.

### Checkboxes & Radio Buttons
- 20x20px dimension with 48x48px touch frame.
- Unchecked: Border `1.5px solid #8A8A8A`, background `#FFFFFF`.
- Checked: Background `#D7282F`, border `#D7282F`, checkmark glyph in `#FFFFFF`.

### Bottom Navigation Bar
- Height 64px + safe area bottom inset. Background `#FFFFFF`, border-top `1px solid #E5E5E5`.
- 4 Equal Destinations:
  1. **Inicio:** Home icon
  2. **Tickets:** Clipboard-list icon
  3. **Inventario:** Box/package icon
  4. **Dashboard:** Bar-chart icon
- Active tab: Icon & label colored `#D7282F`, 2px primary red active indicator bar above icon.
- Inactive tab: Icon & label colored `#8A8A8A`. Font `label-sm`.