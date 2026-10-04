# Fetch redirect referrer policy through the actual header owner

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/Fetch/Fetching/Fetching.cpp:1602–1606`,
`ReferrerPolicy/AbstractOperations.cpp:23–54`,
`ReferrerPolicy/ReferrerPolicy.cpp:50–73`, and
`Libraries/LibHTTP/Header.cpp:50–85`.

Source's HTTP redirect algorithm appends the redirect URL, then invokes the
referrer helper on the internal Response. That helper extracts the actual
HeaderList values, selects the last recognized nonempty policy and updates the
Request only when such a policy exists. The pinned generic HTTP extraction
FIXME returns each entire raw value; ReferrerPolicy's string conversion matches
ASCII case without trimming whitespace or splitting commas.

The V redirect caller instead used `get_decode_and_split()` and a lowercase
string membership check. Raw comma and whitespace values could therefore
replace a valid policy, while genuine uppercase tokens were ignored. The
caller now passes the internal Response's actual HeaderList to the existing
acyclic Source referrer algorithm and writes its nonempty result using the
shared enum's Source string conversion. It retains the URL-append and recursive
fetch ordering. No copied headers or synthetic Response are added.

Five focused cases in `fetch/redirect_referrer_header_owner_test.v` run real
Fetch Requests and Responses through `main_fetch()` with the existing transport
host seam. They inspect both the retained Request policy and the Referer header
seen by the second network hop: raw comma values remain invalid; uppercase
tokens work; repeated mixed-case header names preserve last-valid ordering;
later whitespace values stay invalid; and missing, empty or invalid values
preserve the existing policy. Requests also assert the actual redirect URL and
redirect count, and the existing runtime tests retain the no-expansion control.

Before the caller fix, four focused cases failed behaviorally and the fifth
control passed in 10.07 seconds
(`Build/audit-fixes/source-fetch-redirect-referrer-original-default.log`). The
new and existing referrer runtime files then passed in the default two-file
batch in 18.89 seconds (`source-fetch-redirect-referrer-default.log`). The
GC-none five-file batch passed in 49.02 seconds
(`source-fetch-redirect-referrer-gc-none.log`): new redirect cases, existing
referrer runtime, complete Fetch runtime file, raw-response helper and shared
enum/header core owner. The original four failures remain retained separately.

This closes the referrer-policy selection at the actual HTTP redirect caller.
The Request still retains its existing string representation, with the Source
enum converted at that boundary. HTML's Fetch-response policy-container
factory and CSP response parsing remain separate translation slices; no claim
about the complete Fetch redirect algorithm or Source Response/GC graph is made.
