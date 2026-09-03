# HZT Keycloak Login Design QA

## Comparison target

- Source visual truth: `/var/folders/gs/cs00xl6x40d354ldyn4hs36h0000gn/T/TemporaryItems/NSIRD_screencaptureui_ewxyut/截屏2026-09-03 12.10.09.png`
- Source content crop: `.local/design-qa/source-content-exact-3822x1900.png`
- Normalized source: `.local/design-qa/source-content-1911x950.png`
- Browser-rendered implementation: `.local/design-qa/keycloak-login-local-1911x950.png`
- Combined comparison: `.local/design-qa/source-vs-keycloak-pass2.png`
- Viewport: 1911 × 950 CSS px
- Source pixels: 3822 × 1900 at 2× density, normalized to 1911 × 950
- Implementation pixels: 1911 × 950 at deviceScaleFactor 1
- State: desktop login, no validation error, username and password inputs visible together

## Full-view comparison evidence

The normalized reference and rendered Keycloak theme use the same 65%/35% split, hero crop and overlays, brand lockup, central message, capability statistics, bottom curve, form column width, tab treatment, typography hierarchy, fields, actions, and footer placement.

## Focused region comparison evidence

The form region was checked separately because the core requirement depends on its state. Both username and password controls are visible before any submission. The remember checkbox is checked by default, password visibility changes the input from `password` to `text`, and the registration and reset-password links resolve to Keycloak actions. The brand region uses the source logo and wedding image rather than approximated assets.

## Required fidelity surfaces

- Fonts and typography: Chinese system-font stack, weights, sizes, line heights, title hierarchy, and the Kai-style hero mark match the reference.
- Spacing and layout rhythm: panel ratio, form width, vertical offsets, field spacing, stats baseline, and curve position match after the second pass.
- Colors and visual tokens: source red, carbon text, white panel, muted grays, image overlays, focus treatment, and button shadow match.
- Image quality and asset fidelity: exact production logo, full logo, and wedding hero assets are embedded in the Keycloak image with readable permissions.
- Copy and content: visible product copy, labels, tabs, actions, company text, and footer match the data-platform login.

## Comparison history

### Pass 1 — blocked

- [P1] Brand assets returned HTTP 500 because remote Docker `ADD` files were mode `0600`.
- [P2] Hero copy, capability stats, bottom curve, and form column were vertically above the reference.
- Fixes: set downloaded assets to mode `0644`; aligned hero copy by 38 px, form by 42 px, stats bottom offset to 56 px, and curve bottom offset to -154 px.

### Pass 2 — passed

- Post-fix evidence: `.local/design-qa/source-vs-keycloak-pass2.png`.
- No actionable P0/P1/P2 visual mismatch remains.
- Console errors: none.

## Primary interactions tested

- Username and password visible simultaneously.
- Password show/hide control.
- Remember-me default state.
- Registration link.
- Forgot-password link.
- Responsive 390 × 844 rendering without horizontal overflow.

## Findings

No actionable P0/P1/P2 findings remain.

final result: passed
