# Runnin.AI Design References

> Visual reference documentation for Runnin.AI interface design specifications. Maintained in sync with Figma design file.
> 
> **Figma**: https://www.figma.com/design/gmfDCcbt5mQ4Yc6wa0PAye/telas-runnin
> **Last Updated**: May 2026

---

## Design System Overview

### Brand Identity
- **Product Name**: Runnin.AI (stylized as `RUNNIN.AI`)
- **Tagline**: "Feito para Vencedores" (Made for Winners)
- **Theme**: Dark mode native
- **Target Platform**: Mobile-first (iOS & Android)

### Visual Design Language

#### Color Palette
- **Primary Background**: `#000000` (Pure Black)
- **Primary Accent**: `#00BFFF` (Cyan/Turquoise)
- **Secondary Accent**: `#FFFFFF` (White)
- **Text Primary**: `#FFFFFF` (White on dark background)
- **Text Secondary**: `#888888` (Medium Gray - for disabled/secondary text)
- **Border Color**: `#333333` (Dark Gray)
- **Input Background**: `#1A1A1A` (Deep Black)

#### Typography
- **Font Family**: Monospace (appears to use a monospace/code font)
- **Font Weights**: Regular (400) and Bold (700)
- **Font Scales**:
  - Heading 1: 32px (app titles, major sections)
  - Heading 2: 24px (section headings)
  - Body: 16px (standard text)
  - Caption: 12px (helper text, labels)
  - Code/Numbers: 14px (with monospace styling)

#### Spacing Scale
- Base unit: 8px
- Padding options: 8px, 16px, 24px, 32px
- Margins follow same scale
- Consistent 16px padding for screen edges

#### Border & Shadows
- **Button Borders**: 1px solid `#333333` (when visible)
- **Input Borders**: 1px solid `#333333`
- **Shadows**: Minimal — dark theme uses soft grays instead of shadows
- **Corner Radius**: 8px for containers, inputs, buttons

#### Motion & Animation
- **Micro-interactions**: Subtle fade-in on navigation
- **Button States**: Active state uses elevated accent color
- **Loading**: Progress indicators use cyan accent
- **Transitions**: 200-300ms duration for smoothness

---

## Screen Architecture

### 1. **Onboarding Flow** (`01-onboarding/`)
Authentication and user setup pathway.

#### Splash Screen (`SPLASH.pdf`)
- **Purpose**: App launch screen / loading indicator
- **Elements**:
  - Runnin.AI logo (white text + cyan `.AI` block)
  - Tagline: "Feito para Vencedores"
  - Loading indicator bar (cyan)
  - Dark background
- **Duration**: ~2-3 seconds

#### Login Screen (`LOGIN.pdf`)
- **Purpose**: Phone-based authentication entry
- **Layout**:
  - Back button (top-left, outline style)
  - Logo (top-right)
  - Section label: `// LOGIN` (cyan, monospace)
  - Heading: "Entre na corrida" (large, white)
- **Input Fields**:
  - **Phone Number**: `+55 (11) 99999-9999` (with mask)
  - **OTP Code**: 6-digit input with dashes
- **Actions**:
  - Google Sign-In button (with Google icon)
  - "PRÓXIMO ↗" button (cyan, full-width, bottom)
- **State Transitions**: Shows phone → OTP code → Google option

#### Onboarding Flow (`ONBOARDING.pdf`)
- **Purpose**: User setup and preference configuration
- **Screens** (multi-page design):
  - Personal data entry
  - Running level assessment
  - Goal setting
  - Preference configuration (music, notifications, etc.)
  - Coach introduction / welcome screen

### 2. **Main App** (`02-main-app/`)
Core application interface and home experience.

#### Home Screen (`HOME.pdf`)
- **Purpose**: Main navigation hub and activity overview
- **Typical Layout**:
  - Header with user greeting / date
  - Quick stats (recent runs, this week's totals)
  - Upcoming training card
  - Run history list or week view
  - Bottom navigation or floating action buttons
- **Navigation**:
  - Tab bar or drawer with: Home, History, Profile, Settings

#### Assessment Screen (`ASSESSMENT.pdf`)
- **Purpose**: Initial running level assessment or periodic re-assessment
- **Flow**: Series of questions/tests to determine runner level
- **Output**: Level classification (e.g., Beginner, Intermediate, Advanced)

### 3. **Training Flow** (`03-training-flow/`)
Pre-run planning and during-run experience.

#### Training Plan Screen (`TREINO.pdf`)
- **Purpose**: View and customize training plan
- **Elements**:
  - Plan overview (weekly layout)
  - Training sessions with details:
    - Distance / Duration
    - Pace zones (easy, tempo, hard)
    - Coach instructions / tips
  - Start run button
  - Edit / customize options

#### Run Session Screen (`RUN.pdf`)
- **Purpose**: Real-time run tracking and coach interaction
- **Layout** (typical):
  - Map view (top) - GPS tracking
  - Real-time metrics:
    - Distance (km)
    - Time / Pace
    - Heart rate
    - Current pace zone / intensity indicator
  - Coach panel (bottom) - voice/text guidance
  - Controls: Pause, Stop, SOS (emergency contact)
- **Coach Features**:
  - Voice notifications (audio ducking with music)
  - Interactive Q&A
  - Live feedback on pace, form, etc.

#### Plan Loading Screen (`PLAN_LOADING.pdf`)
- **Purpose**: Coach-generated plan preparation screen
- **State**: Loading/thinking animation
- **Message**: "Coach está preparando seu treino..." (Coach is preparing your training)
- **Visual**: Spinning loader with cyan accent

### 4. **Profile & Settings** (`04-profile/`)
User profile and app preferences.

#### Profile Screen (`PERFIL.pdf`)
- **Purpose**: User profile, stats, and settings
- **Sections**:
  - User avatar and name
  - Running stats (total km, runs, personal records)
  - Achievement badges or medals
  - Preferences:
    - Music playlists
    - Notification settings
    - Running preferences (pace zones, heart rate zones)
    - Coach settings (voice, language, feedback style)
  - Account settings (logout, app settings)

#### History/Statistics Screen (`HISTÓRICO.pdf`)
- **Purpose**: Past runs, statistics, and progress tracking
- **Layout**:
  - Run list (reverse chronological)
  - Each run shows:
    - Date / Time
    - Distance, Duration, Pace
    - Map preview
    - Performance rating / coach summary
  - Timeline view or calendar view option
  - Filter/sort options (by date, distance, pace)

### 5. **Loading & State Screens** (`05-loading-states/`)
Interim states and feedback.

#### Loading States
- Spinner with cyan accent
- Progress indicators
- "Coach is thinking..." messages
- Smooth transitions between states

---

## Component Library

### Buttons
**Primary Button** (CTAs)
- Background: Cyan (`#00BFFF`)
- Text: Black or white (high contrast)
- Height: 48px minimum (thumb-friendly)
- Padding: 16px horizontal, 12px vertical
- Corner radius: 8px
- State: Active (full opacity), Disabled (50% opacity)
- Example: "PRÓXIMO ↗", "Começar Treino"

**Secondary Button** (outline)
- Border: 1px solid `#333333`
- Background: Transparent
- Text: White
- Similar sizing to primary
- Example: "← VOLTAR", "Cancelar"

**Text Button** (minimal)
- No background or border
- Text: White or cyan
- Used for: Skip, Learn More, etc.

### Input Fields
**Text Input**
- Background: `#1A1A1A`
- Border: 1px solid `#333333`
- Padding: 12px
- Height: 48px
- Placeholder text: `#666666`
- Focus state: Border color → cyan
- Corner radius: 8px

**Variations**:
- Phone number input (with prefix/mask)
- OTP input (6 digits with dash separators)
- Text input with label above
- Number input (for distance, time, etc.)

### Cards
**Standard Card**
- Background: `#0A0A0A`
- Border: 1px solid `#222222` (optional)
- Padding: 16px
- Corner radius: 8px
- Shadow: Subtle (soft gray overlay)

**Run Summary Card**
- Shows date, distance, time, pace
- Optional: map preview (thumbnail)
- Optional: Coach summary highlight

### Navigation
**Bottom Tab Bar** (likely)
- 4-5 tabs: Home, Treino/Runs, Histórico, Perfil, More
- Active tab: cyan underline or icon color
- Inactive: gray icons

**Header / Top Bar**
- Dark background with logo (top-right)
- Optional back button (top-left)
- Title or section label (cyan, monospace prefix like `// LOGIN`)

---

## Layout Patterns

### Screen Layout Formula
```
┌─────────────────────────────────┐
│ [← BACK]       RUNNIN.AI        │ ← Header (48px)
├─────────────────────────────────┤
│                                 │
│ // SECTION                      │ ← Section label (cyan, monospace)
│                                 │
│ Main Heading                    │ ← H1 (32px, white, bold)
│                                 │
│ [Content area - scrollable]     │
│                                 │
├─────────────────────────────────┤
│  [Primary Button - full width]  │ ← Bottom action
├─────────────────────────────────┤
│ [Bottom Nav] Home Treino Hist.. │ ← Tab bar (56px safe area)
└─────────────────────────────────┘
```

### Spacing Rules
- Screen edge padding: 16px
- Section gap: 24px
- Element gap: 8-16px
- Button height minimum: 48px (thumb-friendly)
- Safe area bottom: 56px (for tab bar)

---

## Key Design Principles

1. **Accessibility First**
   - High contrast (white on black = excellent contrast ratio)
   - Touch targets ≥ 48px
   - No reliance on color alone
   - Clear focus states

2. **Performance-Focused**
   - Smooth 60fps animations
   - No motion sickness triggers (avoid rapid spinning, flashing)
   - Instant feedback on interactions

3. **Dark Theme by Default**
   - Reduces eye strain for outdoor use (running)
   - Battery efficient (OLED displays)
   - Consistent with modern fitness app standards

4. **Clarity Over Decoration**
   - Minimal but strategic use of cyan accent
   - Clean typography hierarchy
   - Clear action buttons
   - No unnecessary visual clutter

5. **Context-Aware**
   - During run: large, glanceable metrics
   - Planning: detailed information
   - History: searchable, comparable data

---

## Implementation Notes

### Colors in Code
```
Cyan Accent: #00BFFF (or RGB: 0, 191, 255)
Black: #000000 (or #0A0A0A for depth)
White: #FFFFFF
Dark Gray: #333333
Medium Gray: #888888
Light Gray: #1A1A1A
```

### Typography in Code
```
Font: System monospace (or fallback: 'Courier New', 'Courier', monospace)
Weights: 400 (regular), 700 (bold)
Letter spacing: +0.5px for section labels (monospace style)
Line height: 1.4x for body, 1.2x for headings
```

### Border Radius
```
Small elements: 4px
Standard: 8px
Large: 12px
```

---

## File Organization

```
references/
├── README.md (this file)
├── think-tank-runcoach-ai.md (technical research)
├── 01-onboarding/
│   ├── splash-screen.png
│   ├── login-phone-input.png
│   ├── login-otp.png
│   ├── onboarding-step-1.png
│   ├── onboarding-step-2.png
│   └── ...
├── 02-main-app/
│   ├── home-screen.png
│   ├── home-with-upcoming-training.png
│   ├── assessment-quiz.png
│   └── ...
├── 03-training-flow/
│   ├── training-plan-overview.png
│   ├── training-plan-detail.png
│   ├── run-session-map.png
│   ├── run-session-metrics.png
│   ├── run-session-coach-panel.png
│   └── ...
├── 04-profile/
│   ├── profile-screen.png
│   ├── profile-stats.png
│   ├── history-list.png
│   ├── history-calendar.png
│   └── ...
├── 05-loading-states/
│   ├── splash-loading.png
│   ├── plan-loading.png
│   └── ...
└── design-pdfs/
    ├── SPLASH.pdf
    ├── LOGIN.pdf
    ├── ONBOARDING.pdf
    ├── HOME.pdf
    ├── TREINO.pdf
    ├── RUN.pdf
    ├── PLAN_LOADING.pdf
    ├── PERFIL.pdf
    ├── HISTÓRICO.pdf
    └── ASSESSMENT.pdf
```

---

## Design Handoff Checklist

When implementing screens based on this reference:

- [ ] Color values match palette (especially cyan accents)
- [ ] Typography follows scale (32, 24, 16, 12px)
- [ ] Spacing uses 8px base unit
- [ ] Button height ≥ 48px
- [ ] Input fields have focus states (cyan border)
- [ ] Navigation follows tab bar pattern
- [ ] Section labels use monospace + cyan (`// SECTION`)
- [ ] Contrast ratio ≥ 4.5:1 (WCAG AA)
- [ ] All interactive elements are keyboard accessible
- [ ] No hover-only interactions (mobile-first)
- [ ] Loading states have animations
- [ ] Error states are clear and helpful
- [ ] Safe area padding applied (especially bottom for tab bar)

---

## Related Files

- **Figma Design File**: https://www.figma.com/design/gmfDCcbt5mQ4Yc6wa0PAye/telas-runnin
- **Technical Architecture**: `think-tank-runcoach-ai.md`
- **Code Base**: `/app/` (Flutter mobile), `/server/` (NestJS backend)

---

## Revision History

| Date | Changes | Author |
|------|---------|--------|
| 2026-05-14 | Initial comprehensive reference guide from PDF & Figma | UX Designer |
| 2026-05-07 | Previous design specs (scattered) | - |

---

*Last Updated: 2026-05-14 by UX Designer*
