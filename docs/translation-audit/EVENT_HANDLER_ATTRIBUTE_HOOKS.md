# Event handler content attributes

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`DOM/EventTarget.cpp:560–573,933–996`, `HTML/HTMLElement.cpp:808–863`,
`HTML/HTMLBodyElement.cpp:105–145`, `HTML/HTMLFrameSetElement.cpp:24–34`, and
both event-handler enumeration headers.

Feature commit `5a4d63b3` translates the exact full attribute-name lookup for all
118 source members. Raw hooks accept `onclick`/`onload`, and event-handler maps
retain the corresponding event names. The vendor entries preserve source case,
including `onwebkitanimationend` → `webkitAnimationEnd`. Unknown and stripped
names return before activation.

The live DOM attribute-change path now runs the source HTMLElement global hook
and the body/frameset Window hook. Parser-created and subsequently changed
attributes reach the same retained handler records. Existing HTML helper calls
enter that dispatch once, avoiding duplicate CSP checks or activation. Removal,
replacement, raw-source retention, and lazy compilation retain their existing
source callback/listener identities. Existing raw-hook tests use the source API.

Four focused DOM cases cover exact name mapping, vendor case, replacement and
removal identity, ordinary versus body/frameset attributes, CSP-before-replacement,
and namespace behavior. Default GC passes in
`Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/source-handler-attribute-hooks-final-default.log`;
the four-file GC-none batch passes in `source-handler-attribute-hooks-gc-none.log`,
including existing raw compilation, UI events, and CSP neighbors. Updated native
Window accessor and raw compiler cases pass in `source-handler-attribute-native-gc-none.log`.

Pinned source details are retained deliberately: HTMLElement still has an
explicit namespace FIXME, and EventTarget's Window-reflection predicate lists
16 names although the WindowEventHandlers header lists 20. The four newer
body/frameset attributes therefore stay on the element in this translation.
The source namespace TODO is not silently replaced with a different algorithm.

Complete source virtual subtype dispatch and element/form/document JavaScript
handler environments remain separate work. This slice installs the actual raw
records; the native readiness binding and active-document identity fixes follow
separately.
