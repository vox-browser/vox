# Source CSP ASCII token and whitespace rules

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/ContentSecurityPolicy/Policy.cpp:43–80`,
`Libraries/LibWeb/Infra/CharacterTypes.h:14–21`,
`AK/StringView.cpp:197–202`, and `AK/CharacterTypes.h:18–21`.

The existing serialized CSP string parser used V's `string.is_ascii()` and
`fields()`. In the checked V compiler, `is_ascii()` accepts only printable
characters from 0x20 through 0x7E. Source's ASCII check accepts every byte below
0x80, including controls. An interior TAB, LF, CR or form feed could therefore
discard a valid directive and allow a later duplicate to become its replacement.
V's `fields()` also separates only space, TAB and LF, whereas Source's directive
value split uses all five ASCII whitespace characters: space, TAB, LF, CR and
form feed.

The parser now tests the actual Source ASCII range and splits values on those
five characters, excluding empty entries as Source's `split_view_if()` does.
The existing first-duplicate, directive classification, strict semicolon split
and ASCII leading/trailing trim behavior are retained. Other ASCII controls,
including NUL, vertical TAB and DEL, remain part of the directive value.

Focused string-input regressions are in
`contentsecuritypolicy/serialized_csp_ascii_token_test.v`. They distinguish all
five whitespace characters, witness first-duplicate preservation after a valid
control-bearing directive, retain non-whitespace ASCII controls and continue
to reject non-ASCII tokens. Before the fix, three focused cases failed and the
non-ASCII control passed in 6.00 seconds
(`Build/audit-fixes/source-csp-ascii-token-original-default.log`). The corrected
default batch passed both the new file and existing directive/parser tests in
9.07 seconds (`source-csp-ascii-token-default.log`). The GC-none three-file
batch also passed: the new token rules, existing directive/parser and existing
policy serialization/event neighbors (`source-csp-ascii-token-gc-none.log`).
The byte-input investigation separately retained its initial partial outcome;
that run is not counted as a clean validation of these token changes.

This is the String branch of Source's serialized CSP parser. Byte-sequence
isomorphic decoding, actual response HeaderList ownership and HTML's policy
factory caller remain separately reviewable. Full native policy/GC ownership
is not implied by these token rules.
