# Detached Liquid Glass Navigation + Gemini-Style Chat

## Overview

Redesign the bottom navigation into two separate floating Liquid Glass islands (3-tab pill left, Avo circle right) and rebuild the Avo chat screen in a Gemini-inspired minimalist style. Fix the chat input positioning to sit above the navbar.

## Navigation Layout

### Left Island (3 Tabs)
- Compact pill (~180px wide), `left: 24px, bottom: safeArea`
- LiquidGlassContainer with native iOS 26 effect
- Sliding bubble highlight with spring physics (existing)
- Icons: Home, Recipes, Profile (26px each)
- Height: 58px, border-radius: 29px

### Right Island (Avo Button)
- Circle, 58px diameter, `right: 24px, bottom: safeArea`
- Separate LiquidGlassContainer (stronger blur differentiation)
- Active state: green glow ring (2px, pulsing animation)
- Inactive state: glass effect matching left island
- Avo image (34px) centered

### Gap
- No fixed width — islands float independently at their respective sides

## Avo Chat Screen (Gemini-Style)

### Header
- Minimal: "Avo" title left, reset button right
- No large mascot in header
- Typing indicator: "Avo is thinking..." subtitle text

### Messages
- **User**: Subtle bubbles right-aligned, accent-color bg, max 80% width, radius 20/20/4/20
- **Avo**: No bubble — full width left-aligned, small avatar (28px) top-left, text below with padding, transparent background
- Spacing: 24px between groups, 8px within same sender
- Empty state: Centered Avo icon (80px) + "How can I help?" + 3-4 suggestion chips (LiquidGlassButton)

### Input Bar
- Positioned in MainScaffold (NOT in AvoChatScreen) as overlay above navbar
- Bottom padding: navbar height (58px) + safeArea + 12px gap
- Pill form (border-radius 24px), LiquidGlassContainer background
- Layout: Quick-actions (+) button | TextField | Send button (inside field)
- Keyboard pushes input + navbar up together (no overlap)

### Theme Support
| Element | Dark | Light |
|---------|------|-------|
| Input pill bg | white 8% opacity | grey.shade100 |
| Input pill border | white 12% opacity | grey.shade200 |
| User bubbles | accent 90% opacity | accent solid |
| Avo text | white 95% opacity | black 90% opacity |

## Architecture

Stack-based in MainScaffold:
```
Stack [
  IndexedStack (tab pages)
  Positioned (chat input — only visible on Avo tab, above navbar)
  Positioned (left navbar island — bottom-left)
  Positioned (right Avo island — bottom-right)
]
```

## Files Changed

| File | Change |
|------|--------|
| `main_scaffold.dart` | Split navbar into two Positioned islands, add chat input overlay |
| `avo_chat_screen.dart` | Full redesign: Gemini-style messages, minimal header, remove input (moved to scaffold) |
| `liquid_glass_widgets.dart` | Add LiquidGlassInputBar if needed |

## Constraints
- Must not break existing tab navigation or deep linking
- Must work in both dark and light mode
- Native iOS 26 Liquid Glass on iOS, BackdropFilter fallback on Android
- Keyboard must push input + navbar up cleanly
- Spring physics animations preserved
