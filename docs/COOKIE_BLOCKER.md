# Cookie warning blocker

`blocking/cookie_blocker.v` hides cookie warnings by default. The policy runs during the
initial page installation and after cosmetic-filter mutation replay, before
subsequent layout and paint updates. This also covers delayed widgets when the
adblocker is disabled.

Set `VOX_BLOCK_COOKIE_BANNERS=0` before launching Vox to preserve a site's consent
UI, including for reference-browser comparisons. Other values retain the
default policy. Disabling the policy stops further mutations; it does not
restore an already hidden widget, so reload the page when changing the policy.

## Recognition and behavior

- Exact vendor root IDs and class tokens recognize supported OneTrust,
  Cookiebot, Didomi, Usercentrics, Quantcast, consentmanager, iubenda, and
  `cc-window` widgets without relying on English text. Hiding a recognized host
  also hides its shadow content.
- Other warnings need a cookie-related identity, cookie text, and an actual
  consent or dismissal control. Generic dialogs need cookie text and a choice
  control. Ordinary policy prose, policy/settings links, and cookie-required
  sign-in dialogs with only Continue/Close controls remain visible.
- Only the outermost recognized container is marked. The blocker preserves the
  DOM and unrelated inline CSS, sets `aria-hidden`, and applies
  `display: none !important` through CSSOM.
- Later passes repair changed display/accessibility properties. An unchanged
  pass does not rewrite attributes or add duplicate display declarations.
- The blocker does not click controls, submit forms, or persist consent choices.
  It is a cosmetic policy: site-specific scroll locks, separate backdrops, and
  native modal-dialog state are not automatically dismissed.

Keep vendor matching specific to actual widget roots. Broad brand-name or
cookie-policy substring matching can hide ordinary page content. Add positive
and negative fixtures when extending recognition.

## Focused verification

`blocking/cookie_blocker_test.v` covers detection, localized roots, policy-content
exclusions, CSS preservation, dynamic insertion, repair/idempotency, and the
environment override. `blocking/main_adblock_cookie_blocker_test.v` covers the refresh
integration with adblock disabled, preserved user CSS, and the override.

With the normal Vox build dependencies installed, run the selected tests using
the repository memory guard:

```sh
python3 tools/run_memory_bounded.py \
  --limit-gib 3 \
  --lock Build/cookie-blocker-tests.lock \
  --report Build/cookie-blocker-tests.json -- \
  v -enable-globals -memory-limit 10G test \
    cookie_blocker_test.v main_adblock_cookie_blocker_test.v
```

## Change audit

2026-11-03: extend the existing initial-load blocker with delayed-warning
refresh, CSSOM repair, precise vendor roots, and control-based recognition.
The focused suite now contains 15 test functions across the two files above.
Formatting/parser checks passed, and 34 isolated assertions passed against the
implementation's actual identity/action helpers. These checks are separate from
native DOM/CSS/browser validation. The native tests were not run in the change
environment because the checkout and required platform dependencies were not
available. No broad regression checkpoint or browser-runtime pass is claimed.
