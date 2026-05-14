# Loading States & Transitions

Interim screens and feedback during data processing.

---

## Splash/Loading Screen

**File**: `SPLASH.pdf`

**Purpose**: App initialization and brand presentation during startup.

### Layout

```
┌─────────────────────────────┐
│                             │
│                             │
│                             │
│                             │
│        RUNNIN .AI           │  ← Logo (white)
│         RUNNIN .AI          │  ←   with cyan ".AI" accent
│                             │
│   FEITO PARA VENCEDORES     │  ← Tagline (gray)
│                             │
│                             │
│   ▓▓▓▓▓▓▓░░░░░░░░░░░░░░    │  ← Loading bar (cyan)
│   (progress: 45%)            │
│                             │
│                             │
│                             │
└─────────────────────────────┘
```

### Behavior

- **Duration**: 2-3 seconds (or until backend initializes)
- **Progress Bar**: Fills left to right over 2-3 seconds
- **Animation**: Smooth progress fill (easing)
- **Audio**: Optional: brand sound/jingle
- **Next**: Automatically transitions to Login or Home (based on auth state)

### States

**State 1: Initial Load**
- Logo visible
- Progress bar at 0%
- Tagline present

**State 2: Loading (0-100%)**
- Progress bar incrementally fills
- Bar color: cyan (`#00BFFF`)
- Background: full black
- No user interaction (locked)

**State 3: Complete**
- Progress bar fills to 100%
- Optional: checkmark or fade-out
- Transition fade to next screen

---

## Plan Generation Loading

**File**: `PLAN_LOADING.pdf`

**Purpose**: User feedback while Coach AI generates training plan.

### Layout

```
┌─────────────────────────────┐
│                             │
│                             │
│                             │
│       RUNNIN .AI            │  ← Smaller logo
│                             │
│   Coach está preparando     │  ← Primary message
│   seu treino...             │
│                             │
│         ◐ ◑ ◒ ◓             │  ← Spinning loader
│         ◔ ◕ ◖ ◗             │  (8-frame rotation)
│                             │
│   Analisando seu nível      │  ← Rotating submessages
│   baseado em sua experiência│
│                             │
│                             │
└─────────────────────────────┘
```

### Behavior

- **Duration**: 1-5 seconds (typical 2-3 seconds)
- **Spinner**: 8-frame rotating animation at 200ms per frame
- **Color**: Cyan for spinner
- **Message Rotation**: Changes every 1-2 seconds

### Messages (Rotating)

1. "Coach está preparando seu treino..."
2. "Analisando seu nível baseado em sua experiência..."
3. "Personalizando plano para você..."
4. "Quase pronto!"

### Error Fallback (>5 seconds)

If generation takes >5 seconds:

```
┌─────────────────────────────┐
│                             │
│   RUNNIN .AI                │
│                             │
│   Demorando mais que o      │  ← Helpful message
│   esperado...               │
│                             │
│   Ainda estou trabalhando!  │
│                             │
│   ⏱️ Retry [   ]  [Default]  │  ← Fallback options
│                             │
└─────────────────────────────┘
```

Options:
- **Retry**: Restart generation attempt
- **Use Default Plan**: Fallback to pre-made beginner plan

---

## Generic Loading Indicators

### Full-Screen Loading

Used when loading major screens (e.g., History, Profile).

```
┌─────────────────────────────┐
│ ← BACK      RUNNIN .AI      │  ← Header remains visible
├─────────────────────────────┤
│                             │
│  ░░░░░░░░░░░░░░░░░░░░░░    │  ← Skeleton loader for title
│                             │
│  ░░░░░░░  ░░░░░░░░          │  ← Skeleton for subtitle
│                             │
│  ┌─────────────────────────┐ │
│  │ ░░░░░░░░░░░░░░░░░░░░░░  │ │  ← Card skeleton
│  │ ░░░░░░░░░░░░░░░░░░░░░░  │ │
│  │ ░░░░░░░░░░░░░░░░░░░░░░  │ │
│  └─────────────────────────┘ │
│                             │
│  ┌─────────────────────────┐ │
│  │ ░░░░░░░░░░░░░░░░░░░░░░  │ │  ← Card skeleton
│  │ ░░░░░░░░░░░░░░░░░░░░░░  │ │
│  │ ░░░░░░░░░░░░░░░░░░░░░░  │ │
│  └─────────────────────────┘ │
│                             │
│  [Shimmer effect moving →]   │
│                             │
└─────────────────────────────┘
```

**Style**:
- Skeleton loaders match final layout
- Shimmer/fade animation: 800ms cycle
- Background: slightly lighter than normal (`#0A0A0A` → `#111111`)

### Inline Loading (Small Spinners)

Used for button actions, small data fetches.

```
Button Loading State:
┌────────────────────┐
│ [⟳ Loading...]     │  ← Spinner + text
│ (button disabled)   │
└────────────────────┘

Inline Loading:
Some text... [⟳] ...rest of text
(spinner rotates within text flow)
```

**Spinner Style**:
- Unicode character or SVG: `⟳`, `⟲`, or custom SVG
- Color: cyan
- Size: 16-20px
- Rotation speed: 1 second per rotation

---

## Error States & Retry

### Network Error

```
┌─────────────────────────────┐
│                             │
│        ⚠️ ERROR             │  ← Warning icon (yellow/orange)
│                             │
│   Unable to load plan       │  ← Error title
│                             │
│   Please check your        │  ← Explanation
│   internet connection       │
│   and try again.           │
│                             │
│   ┌──────────────────────┐ │
│   │ [Retry ↗]            │ │  ← Primary action
│   └──────────────────────┘ │
│   ┌──────────────────────┐ │
│   │ [Go Back]            │ │  ← Secondary action
│   └──────────────────────┘ │
│                             │
└─────────────────────────────┘
```

### Timeout Error

```
┌─────────────────────────────┐
│                             │
│   ⏱️ REQUEST TIMEOUT        │  ← Icon + title
│                             │
│   The request took too      │
│   long. Your connection     │
│   might be slow or the      │
│   server is busy.           │
│                             │
│   [Retry ↗]  [Use Cache]    │  ← Fallback option
│                             │
└─────────────────────────────┘
```

---

## Transition Animations

### Screen Transition

- **Fade In**: 200-300ms on content entry
- **Slide Up**: 300ms for modals/overlays
- **Cross-fade**: 200ms when replacing content

### Button State Transitions

```
Idle → Pressed → Loading → Success/Error

Colors:
Idle:    Cyan (#00BFFF)
Pressed: Darker cyan (#0096CC)
Loading: Cyan with spinner
Success: Green (#00C800) + checkmark ✓
Error:   Red (#FF3333) + X
```

---

## Timing Guidelines

| Action | Loading Duration | Max Wait | Feedback |
|--------|------------------|----------|----------|
| Login OTP | <1s | 3s | Spinner |
| Home page load | <2s | 5s | Skeleton loaders |
| Training plan gen | 2-3s | 10s | Animated spinner + messages |
| Run start | <500ms | 1s | Brief splash |
| History fetch | <1s | 3s | Skeleton loaders |
| Location fix (GPS) | <5s | 10s | "Getting GPS fix..." |

**Rule**: If >2 seconds, show feedback. If >5 seconds, offer fallback option.

---

## Accessibility Notes

- **Animations**: Respect `prefers-reduced-motion` preference
- **Color-Blind**: Don't rely on color alone for status (use icons + text)
- **Screen Reader**: Announce loading state ("Loading, please wait")
- **Spinning/Flashing**: <3 Hz to avoid seizure risk (WCAG)

---

## Implementation Checklist

- [ ] Splash screen shows on cold start
- [ ] Loading indicators appear for >500ms delays
- [ ] Skeleton loaders match final layout
- [ ] Spinners rotate smoothly (60fps)
- [ ] Messages update while loading
- [ ] Retry button appears on errors
- [ ] Timeout after 10 seconds max
- [ ] Motion preference respected (no animation if disabled)
- [ ] Accessibility: loading state announced
- [ ] Text visible during image loads (font-display: swap)

---

**Reference**: `SPLASH.pdf`, `PLAN_LOADING.pdf`
**Last Updated**: 2026-05-14
