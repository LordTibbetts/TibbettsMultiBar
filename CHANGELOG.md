# Tibbetts MultiBar – Changelog

## 1.0.8 (optimized)
- Fix: `repBar.bg` and `repText` were created *after* the code that tried to use them — initialization was silently skipped on first load
- Fix: Duplicate `addon.GetDB` definition — first definition (EnsureProfileTables-based) was silently overwritten by the second; removed the dead first definition
- Fix: Dead `EnsureDB` function defined inside `ApplyDefaultsTo` body — was unreachable, now removed
- Fix: `LayoutBars` gap was always 0 (`tonumber(0) or 2` → should be `tonumber(db.repGap) or 2`)
- Fix: `UpdateBorderAndTicks` and `LayoutTicks`/`LayoutBorderTextures` were *both* called from `ApplySettings`, creating two overlapping sets of tick textures on each bar — removed the duplicate calls
- Fix: `HideBlizzardXP` was an unintended global; made local; replaced the duplicated inline hide/show block in `ApplySettings` with a call to the helper
- Fix: Removed unused `ShowBlizzardXP` stub (functionality already covered by `HideBlizzardXP(false)`)
- Cleanup: Standardised DB access in `UpdateBar`, `UpdateReputation`, `ConfigureRepDragging`, and `OnSizeChanged` to always use `EnsureDB()` — previously used a fragile mixed-lookup pattern

## 1.2.2
- Fix: removed stray escape characters in Config.lua (syntax error near \\)


## 1.2.1
- Fix: restored missing XP Texture picker controls in options (prevents nil textureBtn error)


## 1.2.0
- Options: removed Tick Opacity; tick dividers are now solid lines controlled only by tick presets
- Options: removed Gap controls; XP/Rep spacing uses a fixed internal value
- Bars: XP and Reputation are now independent (Rep has its own Texture/Font selectors)


## 1.1.9
- Options: moved Background Opacity into the Background Color picker (removed separate opacity slider)


## 1.1.8
- Fix: Options UI RefreshUI syntax error; refresh now uses SafeRefreshUI wrapper


## 1.1.6
- Fix: reputation color picker opacity slider now applies correctly (explicitly syncs OpacitySliderFrame)


## 1.1.5
- Fix: background texture anchoring (removed SetAllPoints(true)) to eliminate 1px gaps at top edge


## 1.1.4
- Options: refreshes UI on panel open and tab switches so saved choices are visible immediately


## 1.1.3
- Fix: removed remaining ApplyDefaults() call in PLAYER_LOGIN; initialization now uses EnsureDB()


## 1.1.2
- Fix: EnsureDB no longer calls missing ApplyDefaults() on TBC/Classic; defaults applied via ApplyDefaultsTo


## 1.1.1
- Fix: Reputation color now applies correctly with Profiles (ApplySettings now uses active profile DB)


## 1.1.0
- Profiles: choose which profile is used as the global "default" when using one profile for all characters


## 1.0.9
- Options: added Reputation color picker (hidden when XP/Rep are linked)


## 1.0.8
- Fix: Reputation progress now reads correct values on Classic/TBC (GetWatchedFactionInfo unpack)
- Fix: Reputation/XP updates now use the active profile DB


## 1.0.7
- Options: moved Profiles into its own tab; main settings tab renamed to General
- Options: fixed Profiles layout (no overlap)


## 1.0.6
- Bars: tick dividers inset 1px to eliminate top-edge "indent" on Rep bar
- Added lightweight Profiles (Default + per-character) with "Use one profile for all characters" toggle


## 1.0.5
- Options: added manual numeric entry boxes for Width/Height
- Options: fixed Texture/Font picker buttons using UniversalPicker (LSM-aware)
- Bars: tick dividers now render behind bar/border to match XP/Rep look
- Options: spacing tweaks in Reputation and Advanced sections
- Fix: ColorPicker OK button compatibility on Classic/TBC


## 1.0.4
- Rebuilt Options UI cleanly for Classic/TBC: unified single-page layout + collapsible Advanced
- Eliminated upvalue-limit and syntax issues from prior unified-options iterations


## 1.0.3
- Unified options: merged General + Appearance into a single streamlined page
- Added collapsible Advanced section for rarely-used settings


## 1.0.1
- Rep bar ticks now render under the border (removes top-edge notches)
- Streamlined Appearance tab with optional Link XP & Rep appearance (hides duplicate Rep controls)


## 1.0.0
- Universal texture & font picker with previews + search
- Tick presets (None / 10% / 20%)
- Optional tick percentage tooltips on hover
- Blizzard-style color pickers with opacity sliders (XP/Rep)
- XP/Rep tick rendering unified and clamped
- Optional linking of XP & Reputation appearance settings
- Compatible with Retail, Classic Era, TBC Anniversary, and Wrath
## v1.1.6 – Multi-client compatibility pass

### Midnight (12.x) retail
- `HideBlizzardXP` now hides `StatusTrackingBarManager` (the new unified tracking
  bar host) instead of individual Classic-only frame names that don't exist in 12.x.
- `C.GetMaxLevel()` no longer calls the removed `GetMaxPlayerLevel`; it now tries
  `MAX_PLAYER_LEVEL` global first, then `GetMaxPlayerLevel` (Classic), then
  `UnitLevel("player")` as a proxy, then a hard-coded table (Midnight = 90).
- All `UnitLevel` calls wrapped in `pcall` for defensive safety on 12.x.

### TOC file audit
- `_Mainline.toc`  — 120001 (Midnight / retail current)
- `_Vanilla.toc`   — 11508  (Classic Era + Season of Discovery 1.15.x)
- `_TBC.toc`       — 20505  (TBC Anniversary 2.5.5)
- `_BCC.toc`       — 20505  added as legacy alias; TBC Anniversary clients
                             still recognise the old `-BCC` suffix
- `_Mists.toc`     — 50503  (Mists of Pandaria Classic, current progression)
- `_Classic.toc`   — 11508  (lowest-priority Classic fallback for any future tier)
- `_Wrath.toc`     — 30400  (private servers / Titan Reforged)
- `_Cata.toc`      — 40402  (private servers)
- Base `TibbettsMultiBar.toc` — 120001 generic last-resort
