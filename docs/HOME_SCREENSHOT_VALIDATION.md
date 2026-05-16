# HOME Screen — Screenshot Validation Report

> **Issue:** SUP-413 — [HOME-C1] Screenshot Validation  
> **Date:** 2026-05-15  
> **Figma source:** `gmfDCcbt5mQ4Yc6wa0PAye` node `1:5269`  
> **Figma URL:** https://www.figma.com/design/gmfDCcbt5mQ4Yc6wa0PAye/telas-runnin?node-id=1-5269

---

## Overall Fidelity Estimate: ~72%

Target: >95%. Gap: ~23 pp. Primary blocker: Hero placeholder.

---

## Section-by-Section Analysis

| # | Section | Figma Height | Status | Fidelity | Notes |
|---|---------|-------------|--------|----------|-------|
| 0 | **Hero / Header** | ~490 px | 🔴 Placeholder | ~5% | Map + 12 icon overlays + vector charts not rendered; `_HeroPlaceholder` shows debug text at 200 px |
| 1 | Coach.AI Brief + INICIAR SESSÃO | ~120 px | ✅ Implemented | ~90% | Orange left-border card + cyan CTA button; correct colors & typography |
| 2 | COACH.AI > NOTIFICAÇÕES (5 cards) | ~400 px | ✅ Implemented | ~88% | SectionHeading, 5-color accent cycling, expanded Coach card; minor spacing gaps |
| 3 | SEMANA — 7-day grid | ~230 px | ✅ Implemented | ~90% | WeekGrid per SUP-404; correct states (done/today/future), volume bar |
| 4 | PERFORMANCE — 2×2 MetricCard | ~400 px | ✅ Implemented | ~85% | MetricCard per SUP-403; Benchmark card cyan bg; ZoneBar present |
| 5 | COACH.AI RESUMO SEMANAL | ~250 px | ✅ Implemented | ~85% | Orange border card with 3 sub-blocks; correct label/body styles |
| 6 | STATUS CORPORAL — 2×2 | ~380 px | ✅ Implemented | ~83% | Prontidão/Sono/Carga/Hidratação; segmented selector; bar charts |
| 7 | ÚLTIMA CORRIDA | ~160 px | ✅ Implemented | ~80% | Run card with distance, pace, duration; header format matches |
| — | Bottom Tab Bar | ~78 px | ✅ Implemented | ~82% | FigmaBottomNav with 5 tabs; RUN FAB present; outer ring / shadow needs verify |

### Extra sections NOT in Figma spec (structural drift)

| Section | Impact |
|---------|--------|
| `_CyberStatusBar` (WATCH / AUDIO chips) | Adds ~60 px not in Figma layout |
| `_UserInfoCards` (PESO / ALTURA / IDADE / FREQ) | Adds ~80 px grid not in spec |
| `_SkinSection` (theme color switcher) | Adds ~120 px not in spec |
| `_MenuSection` | Adds ~200 px quick-links not in spec |

These extra sections push the overall structural layout off-spec and contribute to the fidelity gap.

---

## Weighted Fidelity Calculation

```
Hero (13% weight)              × 5%  =  0.65%
Sections 01–07 (70% weight)    × 86% = 60.2%
Bottom tab (10% weight)        × 82% =  8.2%
Extra sections penalty (7%)    × 30% =  2.1%
─────────────────────────────────────────────
Estimated total fidelity             ≈ 71%
```

---

## Gap Punch List (ordered by impact)

### 🔴 Critical

1. **Hero placeholder** — `_HeroPlaceholder` at 200 px must be replaced with:
   - Full-bleed map background image (`imgContainer` asset)
   - User name + date overlay ("07.MAR.292 — BOM DIA, LUCAS")
   - "HOJE" + session type + "5K" distance + pace target display
   - 12 MuiSvgIconRoot icon overlays (18–22 px)
   - 3 vector area chart overlays (imgVector, imgVector1, imgVector2)
   - Target height: ~490 px

### 🟡 High

2. **Remove extra sections** not in Figma:
   - `_UserInfoCards` (PESO/ALTURA/IDADE/FREQ 4-card row)
   - `_SkinSection` (theme switcher)
   - `_MenuSection` (quick-link grid)
   - `_CyberStatusBar` chips → fold date/greeting into Hero overlay instead

3. **Bottom tab bar RUN FAB**: verify outer ring (`#00D4FF` at 12% opacity, 65 px) and cyan shadow (`rgba(0,212,255,0.31) 0 0 30px`) are rendered correctly.

### 🟢 Low (polish)

4. Section heading `SectionHead` superscript: verify exact 6.6 px JetBrains Mono Regular at all call sites.
5. Notification card spacing: gap between cards is 6 px in code; Figma shows stacked with no explicit gap visible — verify rendered gap.
6. `_CoachMessageCard` button: code uses full-width layout via `Column`; Figma shows it is `fullwidth × 45.955 px` — verify height matches.

---

## Conclusion

The 7 content sections (01–07) are implemented with good fidelity (~85% average). The main blocker to reaching the >95% target is the Hero placeholder, which accounts for ~13% of the Figma canvas and is currently a debug stub. The structural drift from extra non-Figma sections also reduces the layout fidelity score.

**Recommended next step:** Create a dedicated issue for the Hero asset implementation (requires Figma map asset export from the design team), and create a cleanup issue to remove the extra non-Figma sections.
