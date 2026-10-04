# Referrer response parsing uses the actual extracted header values

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/ReferrerPolicy/AbstractOperations.cpp:23–41`,
`ReferrerPolicy/ReferrerPolicy.cpp:52–75`,
`Libraries/LibHTTP/HeaderList.cpp:194–225`, and
`Libraries/LibHTTP/Header.cpp:50–85`.

The Source response helper extracts `Referrer-Policy` header values, then keeps
the last nonempty recognized policy. Pinned Header extraction retains one raw
value for this name and preserves its generic-header parsing FIXME. It does
not split a raw comma-bearing value or trim a raw whitespace-bearing value.
The V response helper instead used `get_decode_and_split`, which changed both
behaviors before its otherwise faithful token loop.

The helper now calls the existing actual HeaderList extraction algorithm.
Missing values and extraction failure retain the empty-policy outcome. The
existing redirect helper still changes the actual Request only when the
resulting policy is nonempty. The older redirect fixture now uses two actual
headers for its last-valid-policy case; its previous single comma-bearing
header expected behavior absent from pinned Source.

Three new cases use real Fetch Responses, HeaderLists and Requests. They prove
that a whole `origin, no-referrer` value is invalid and leaves redirect policy
unchanged; a later whitespace-bearing header is not trimmed into a valid
policy; case-insensitive repeated names preserve actual value order; separate
valid headers still select the last valid policy; and missing headers preserve
the Request's existing policy. The two raw-value cases failed the clean
baseline in 9.83 seconds while the separate-value control had no failures
(`Build/audit-fixes/source-referrer-header-values-original-default.log`).
The corrected new cases and existing referrer-policy file both passed with
default GC in 28.70 seconds (`source-referrer-header-values-default.log`).
The final GC-none batch passed all four files in 34.98 seconds
(`source-referrer-header-values-gc-none.log`): the new cases, existing referrer
API, actual header-value extraction and HeaderList operations. Request and
Response behavior is checked without garbage collection.

This fixes this existing Source response-helper entry point. Fetch's duplicate
redirect caller and HTML's response PolicyContainer factory still perform
their previous independent splitting and need separate caller translations.
CSP response parsing and complete shared enum/GC/realm ownership are separate.
No specification-inspired parser behavior replaces pinned Source's FIXME.
