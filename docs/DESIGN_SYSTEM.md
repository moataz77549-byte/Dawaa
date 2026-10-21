# Design system

Primary #123F42, teal #238982, gold #DAB977, surface #F5F8F7, navy #24334B.
Material 3 cards with 20–26 dp corners and restrained motion. Native system Arabic
fallback font respects accessibility scaling, with an in-app multiplier .9–1.5.
Arabic RTL default, English LTR; both language and dark-mode preferences persist.

Five bottom tabs: home, human body, diseases, medicines, library. App bar links
to downloads/settings. Detail pages expose selectable text, license/reference
and review state. Online preview and permanent download are different actions.
Download confirmation shows scope, version, bytes, license and dependencies.
No future feature is presented as an active button; roadmap is explanatory text.

Adaptive scrollable layouts avoid fixed content heights. Widget coverage verifies
first-open content and RTL/LTR switching. Small-screen/high-text-scale visual
inspection and screenshots on Android remain required before Stage 1 acceptance.
