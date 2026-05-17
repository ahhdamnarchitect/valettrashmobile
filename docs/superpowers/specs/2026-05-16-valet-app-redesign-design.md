# Valet App — 2026 Redesign Spec

**Date:** 2026-05-16  
**Status:** Approved — ready for implementation planning  
**Project:** `valettrashmobile/mobile` (Flutter 3.41.9, Dart, Supabase)

---

## 1. Design Philosophy

### Six Principles

1. **Dark-first, OLED-optimized.** Background is `#08090c` — not pure black. Pure black (#000000) creates pixel bleed halos on OLED. Near-black with a slight warm undertone reads as intentional, not default.

2. **Role-colored, not role-styled.** Every role (resident, worker, manager, owner) shares the same dark base, component shapes, and type scale. Only the accent color changes. This creates a single cohesive product, not five separate apps bolted together.

3. **Status over everything.** The most important piece of information on any screen is the current operational state: Is my pickup scheduled? Is my worker clocked in? How many stops are left? This surfaces as the hero element on every home screen.

4. **One primary action per screen.** The most important action is always a full-width button anchored to the bottom. No competing CTAs. No ambiguity.

5. **Micro-interactions on every state change.** If something changes — a pickup becomes active, a worker clocks in, a notification arrives — the UI animates it. The app feels alive, not static.

6. **Skeleton-first loading.** No spinners anywhere in the app. Every screen that loads data shows a shimmer skeleton while waiting. Perceived performance is real performance.

### Competitive Context

The two largest competitors (Valet Living, Trash Butler) have mediocre, functional-but-ugly apps. One competitor team specifically noted they use dark background for field workers because of readability in sunlight — they knew it mattered but didn't fully execute. **This redesign sets the standard for the category.**

---

## 2. Color System

### Surface Scale

| Token | Value | Usage |
|---|---|---|
| `background` | `#08090c` | Root scaffold background |
| `surface1` | `#0f1014` | Cards, bottom sheets, modals |
| `surface2` | `#161820` | Nested cards, input backgrounds |
| `border` | `#1e2128` | Card borders, dividers |
| `borderSubtle` | `#13141a` | Very subtle separators |

### Text Scale

| Token | Value | Usage |
|---|---|---|
| `textPrimary` | `#f0f0f8` | Headings, primary labels |
| `textSecondary` | `#8b8b9e` | Supporting text, subtitles |
| `textMuted` | `#4a4a5a` | Timestamps, disabled, captions |

### Role Accent Colors

Each role gets one accent. Used for: hero card borders/glows, active tab indicators, primary buttons, status badges, and icon tints. **Never mix accents across roles.**

| Role | Color | Hex | Rationale |
|---|---|---|---|
| Resident | Emerald | `#10b981` | Premium service. Green = active, all good, trust. |
| Worker/Driver | Amber | `#f59e0b` | High visibility in sunlight. Urgency signaling. |
| Property Manager | Indigo | `#6366f1` | Data authority. Portfolio and dashboard energy. |
| Operations Manager | Indigo | `#6366f1` | Shares PM accent — same tool, different data set. |
| Owner/Super Admin | Purple | `#a855f7` | Executive overview. Rare access, feels special. |

### Semantic Colors (shared)

| State | Color | Hex |
|---|---|---|
| Success | Emerald | `#10b981` |
| Warning / Urgent | Amber | `#f59e0b` |
| Error / Violation | Red | `#ef4444` |
| Info | Sky | `#38bdf8` |

### Glassmorphism Recipe

Used for hero status cards on resident and worker home screens:

```
background: accent.withOpacity(0.07)
border: 1px solid accent.withOpacity(0.18)
borderRadius: 16px
backdropFilter: blur(20px) [web only — native uses container decoration]
```

On mobile native, achieve depth using layered gradients instead of real blur (Flutter's `BackdropFilter` has performance implications on lower-end Android devices).

---

## 3. Typography System

**Font:** Geist by Vercel — available free via `google_fonts` package.

**Rationale:** Tallest x-height in the shortlist, sharpest at small sizes on OLED screens, engineered for data-dense technical UIs. Numbers (stats, stop counts, timestamps) are particularly well-formed.

### Type Scale

| Name | Size | Weight | Letter Spacing | Usage |
|---|---|---|---|---|
| Display | 28sp | 800 | -0.04em | Screen hero titles |
| Headline | 20sp | 700 | -0.03em | Section heroes, card headers |
| Title | 15sp | 700 | -0.01em | List item titles, section labels |
| Body | 14sp | 400 | 0 | General content, descriptions |
| Body Strong | 14sp | 600 | 0 | Emphasized body, data values |
| Caption | 10sp | 700 | +0.12em | ALL CAPS section labels, badges |
| Number Hero | 36–48sp | 800 | -0.05em | Big stat displays (stop count, streak) |

### Implementation

```dart
// In AppTheme
static TextTheme get textTheme => GoogleFonts.geistTextTheme(
  ThemeData.dark().textTheme,
).copyWith(
  displayLarge: GoogleFonts.geist(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1.12),
  headlineMedium: GoogleFonts.geist(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.6),
  titleMedium: GoogleFonts.geist(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.15),
  bodyMedium: GoogleFonts.geist(fontSize: 14, fontWeight: FontWeight.w400),
  labelSmall: GoogleFonts.geist(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
);
```

---

## 4. Component Library

**Foundation:** `shadcn_flutter` — 84+ components in the shadcn/ui aesthetic, used in place of Material widgets throughout the app. `MaterialApp` and `ThemeData` remain as the shell (required by Flutter); `shadcn_flutter` components replace individual Material widgets at the screen level. Produces significantly more premium results than Material 3 defaults without extensive theming work.

**Key components used:**

| Component | shadcn_flutter widget | Usage |
|---|---|---|
| Cards | `ShadCard` | Every content block |
| Buttons (primary) | `ShadButton` | Primary CTAs |
| Buttons (ghost) | `ShadButton.ghost` | Secondary actions |
| Badges | `ShadBadge` | Status indicators |
| Alerts | `ShadAlert` | Error/success messages |
| Dialogs | `ShadDialog` | Confirmations |
| Progress | `ShadProgress` | Route progress |
| Toast | `ShadToast` | In-app feedback |
| Avatar | `ShadAvatar` | User/property icons |

**Custom components** (built on top of shadcn_flutter primitives):

- `RoleHeroCard` — the glassmorphism status card at the top of each home screen
- `StatTile` — the 3-stat row (streak, violations, rating)
- `SkeletonCard` — shimmer placeholder matching real card dimensions
- `GlowBadge` — status badge with accent color glow effect
- `RoleBottomNav` — bottom navigation bar with role-specific accent

---

## 5. Animation System

**Libraries:**
- `flutter_animate` (^4.5.0) — all micro-interactions and page entry animations
- `rive` (^0.13.16) — hero state machine animations
- `lottie` (^3.1.2) — success/error feedback

### Animation Map

| Interaction | Library | Spec |
|---|---|---|
| Page entry | flutter_animate | Cards fade + translateY(8px→0), staggered 50ms/item, 200ms curve |
| Button tap | flutter_animate | scale(1.0→0.95→1.0), 150ms spring physics |
| Tab switch | flutter_animate | Fade through, 180ms |
| Pickup status change | Rive | State machine: Pending → Active → Completing → Done |
| Clock In / Out | Rive | Button morphs to spinner → success check, route card slides up |
| Success feedback | Lottie | Checkmark burst, 800ms, plays once |
| Error feedback | flutter_animate | Horizontal shake, 400ms |
| Skeleton loading | shimmer | All data screens, accent color shimmer sweep |
| Pull-to-refresh | flutter_animate | Custom spring bounce on refresh indicator |

### Rive Files Needed

1. `pickup_status.riv` — 4 states: idle, active, completing, done
2. `clock_in.riv` — 3 states: idle, clocking_in, on_duty  
3. `onboarding_hero.riv` — looping ambient animation on auth screen

All Rive files to be designed at 1:1 ratio for the target display area. Free Rive Community files can be used as starting point; customize to match color system.

---

## 6. Navigation Architecture

**Pattern:** Persistent bottom tab bar, role-specific tabs.

Bottom bar uses `shadcn_flutter` styled nav with accent-colored active indicator. Active tab icon gets a subtle glow matching the role accent.

### Tab Definitions by Role

**Resident** (4 tabs):
1. Home — pickup status, tonight's schedule
2. History — past pickups, timeline
3. Notifications — all alerts from property manager
4. Profile — account, unit info

**Worker/Driver** (4 tabs):
1. Route — current route, stop count, clock in/out
2. Comebacks — missed pickup requests
3. Violations — report and history
4. Profile — worker info, status

**Property Manager** (4 tabs):
1. Portfolio — all assigned properties, stats overview
2. Residents — per-property resident list, invite codes
3. Notify — send notifications (property-wide or individual)
4. Settings — account, preferences

**Operations Manager** (4 tabs):
1. Dashboard — worker status, tonight's runs, comeback count
2. Workers — assigned workers, detail view
3. Comebacks — today + 7-day history
4. Notify — resident communication

**Owner/Super Admin** (4 tabs):
1. Overview — portfolio KPIs, all properties
2. Properties — property list + detail
3. Analytics — charts (fl_chart) for occupancy, service rates
4. Settings — account + admin controls

**Transition between screens within a tab:** Shared axis horizontal (same level), shared axis vertical (drill-down). Implemented using the `animations` package (`SharedAxisTransition`, `TransitionType.horizontal/vertical`) wrapped in custom `PageRouteBuilder`.

---

## 7. Screen Specifications

### Auth Screen (shared)

**Layout:** Centered, full-screen dark background (`background`). Lottie/Rive ambient animation plays behind the form area.

**Elements:**
- App wordmark: "Relaxed Living" — Geist 18sp/700, letter-spacing 0.08em, uppercase, color: `textMuted`
- Tagline: "Valet Trash Service" — Geist 13sp/400, `textMuted`
- Email field: `ShadInput` full width
- Password field: `ShadInput` obscured, trailing eye-toggle icon
- Sign In button: `ShadButton` full width, accent color (no role yet — use emerald default)
- Toggle text: "Don't have an account? Sign up" — `ShadButton.link`
- Resident Invite Code button: `ShadButton.outline` with key icon

**Animation:** Form fields fade + slide up 8px with `flutter_animate`, 200ms stagger on screen enter. Error message shakes horizontally.

---

### Resident — Home Screen

**Hero card (RoleHeroCard):**
- Background: emerald glassmorphism recipe
- Eyebrow: "TONIGHT'S SERVICE" — Caption
- Title: Property name — Headline
- Subtitle: "Unit {number} · Window 6:00 – 10:00 PM" — Body
- Status badge: GlowBadge — "Scheduled", "Active · Est. 8:15 PM", "Completed ✓", or "Not Scheduled"
- Pickup status Rive animation plays in the badge area

**Stats row (3 tiles):**
- Pickup Streak (number of consecutive successful pickups)
- Violations (count, red tint if > 0)
- Rating (letter grade A–F or N/A)

**Notification preview:**
- Last notification from property manager as a tappable card
- Taps to Notifications tab

**No pickup tonight:** Hero card shows a muted "No service tonight" state with dimmed border.

---

### Resident — History Screen

Timeline list of past pickups. Each row:
- Date + day of week (Title)
- Status pill: Completed / Missed / Cancelled
- Property + unit (Body, textSecondary)
- Chevron → detail sheet

Loading state: 6 skeleton rows.

---

### Resident — Violations Screen

List of violation records. Each card:
- Violation type (Title)
- Date, is_warning vs penalty badge
- Thumbnail if photo exists
- "View Photo" button → full-screen viewer

Empty state: Illustration + "No violations on record" in textMuted.

---

### Worker — Route Screen

**Hero card (amber accent):**
- Eyebrow: "TONIGHT'S ROUTE"
- Property name — Headline
- Stop count: Number Hero (e.g., "14") + "stops remaining" Body
- Progress bar (ShadProgress, amber fill)
- "Stops Completed" / "Total Stops"

**Primary CTA:** "Clock In" full-width button, amber. Triggers Rive clock_in animation. After clocking in, morphs to "Clock Out".

**Status tiles:**
- Comebacks (count, red if > 0 → taps to Comebacks tab)
- Notes/Issues (count)

**Assignment card:**
- Shows property name, address
- "No active route" state if no assignment

---

### Worker — Comebacks Screen

List of missed pickup requests:
- Unit number (Title)
- Request time (Caption)
- Status: Pending / In Progress / Completed
- "Mark Complete" action on each row

---

### Worker — Violation Report Screen

Multi-step flow:
1. Photo capture (camera or gallery)
2. Violation type selector (chip group)
3. Notes field (optional)
4. Unit number field
5. Confirm + Submit

On submit: Lottie success animation plays, screen pops back to Route.

---

### Property Manager — Portfolio Screen

**Header:** "Portfolio Overview" Headline + property count subtitle

**KPI row:** 4 stat tiles (Properties, Total Units, Verified Residents, Active Codes)

**Property list:** Each property as a `ShadCard`:
- Property name (Title)
- Service window
- Units / Residents counts
- Violations badge (red if > 0)
- Taps to Property Detail

---

### Property Manager — Property Detail Screen

**Header:** Property name, service window edit button

**Sections:**
- Units + residents breakdown
- Invite codes (code, uses remaining, expiry)
- Violations list
- Notification actions: "Alert All Residents" + "Alert Resident"

---

### Operations Manager — Dashboard Screen

**Worker status list:** Each assigned worker as a card:
- Name (Title)
- Status: Off Duty / On Route / Done
- Amber accent if actively on route

**Tonight's runs:** List of nightly_runs with property name, start time, status

**Comebacks tile:** Tappable — Total / Pending / In Progress / Completed counts

**Comeback history:** 7-day resolved comeback count, sparkline (fl_chart)

---

### Owner — Overview Screen

**KPI grid (2×2):**
- Total Properties
- Active Workers Tonight
- Residents Registered
- Pickups Completed (last 30 days)

**Property list:** Minimal rows with route status for tonight

**Analytics tab:** Line charts (fl_chart) for pickups over time, violation frequency, resident activation rate.

---

## 8. Package Stack

```yaml
# pubspec.yaml additions to mobile/

dependencies:
  # Design System
  shadcn_flutter: ^0.0.52         # Drop Material, use shadcn components
  flex_color_scheme: ^8.4.0       # Dark ColorScheme generation
  google_fonts: ^6.2.1            # Geist font

  # Animation
  flutter_animate: ^4.5.0         # Micro-interactions (Flutter Favorite)
  rive: ^0.13.16                  # State machine animations
  lottie: ^3.1.2                  # Feedback animations

  # UI Utilities
  fl_chart: ^0.69.0               # Manager analytics charts
  shimmer: ^3.0.0                 # Skeleton loading
  gap: ^3.0.1                     # Spacing utility
  phosphor_flutter: any            # Icon system (772+ icons, 6 weights — pin version at install)
  animations: ^2.0.0              # SharedAxisTransition for page transitions (Google/Material)
  cached_network_image: ^3.3.1    # Violation photo thumbnails

  # Already present
  supabase_flutter: ^1.10.25
  flutter_dotenv: ^5.1.0
```

**Rive:** Requires free account at rive.app to create `.riv` files. Community files available for starting point — customize colors/states to match design system. **Dev fallback:** During Phase 1–3 implementation, use `flutter_animate` scale + fade combinations as placeholder for all Rive slots. Swap in real `.riv` files during Phase 5 polish without changing any call sites (both are widget-level replacements).

**Lottie:** Free animated assets at lottiefiles.com. Search "checkmark success" and "error" — download JSON, place in `assets/lottie/`.

---

## 9. File Structure Changes

```
mobile/lib/
  core/
    theme/
      app_theme.dart          # flex_color_scheme setup, ColorScheme tokens
      app_colors.dart         # All color constants (replaces brand_colors.dart)
      app_typography.dart     # Geist text theme
      role_theme.dart         # Per-role accent color resolver
    widgets/
      role_hero_card.dart     # Glassmorphism status hero
      stat_tile.dart          # Individual stat display
      skeleton_card.dart      # Shimmer placeholder
      glow_badge.dart         # Accent-colored status badge
      role_bottom_nav.dart    # Bottom navigation bar
      primary_button.dart     # Animated full-width CTA
  assets/
    lottie/
      success.json
      error.json
    rive/
      pickup_status.riv
      clock_in.riv
      onboarding_hero.riv
```

---

## 10. Implementation Phases

### Phase 1 — Foundation (start here)
1. Add all packages to `pubspec.yaml`
2. Create `app_colors.dart`, `app_typography.dart`, `role_theme.dart`
3. Wire `flex_color_scheme` dark theme in `ValetApp`
4. Build shared widgets: `RoleHeroCard`, `StatTile`, `SkeletonCard`, `GlowBadge`, `RoleBottomNav`
5. Redesign `SimpleAuthScreen` with new components + Lottie background

### Phase 2 — Resident Flow
6. Redesign `ResidentDashboardScreen` (all 4 tabs)
7. Add pickup_status Rive animation to home screen
8. Skeleton loading on all resident data fetches

### Phase 3 — Worker Flow
9. Redesign `WorkerDashboardScreen` (all 4 tabs)
10. Add clock_in Rive animation
11. Redesign `ViolationReportScreen` multi-step flow

### Phase 4 — Management Flow
12. Redesign `PropertyManagerDashboardNewScreen`
13. Redesign `ManagerDashboardScreen`
14. Add fl_chart analytics to Owner dashboard
15. Redesign `OwnerDashboardScreen`

### Phase 5 — Polish
16. Page transition animations (shared axis)
17. Pull-to-refresh animations
18. Lottie success/error feedback on all form submits
19. Final QA across all 5 roles

---

## 11. Non-Goals

- No React/web rebuild — Flutter only
- No new features — this is a visual redesign of existing functionality
- No route mapping (Mapbox) — Phase 2 backlog item
- No push notification changes — UI only
- No backend changes — Supabase schema unchanged

---

*Spec written 2026-05-16. Visual companion session: `.superpowers/brainstorm/170-1778924777/`*
