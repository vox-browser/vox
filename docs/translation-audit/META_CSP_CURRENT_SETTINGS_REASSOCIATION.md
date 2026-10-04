# Meta CSP append keeps its Source current-settings owner

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/HTMLMetaElement.cpp:203–223`,
`HTML/Scripting/WindowEnvironmentSettingsObject.cpp:134–138`, and
`HTML/Scripting/Environments.cpp:493–497`.

Meta CSP's pinned Source body sets the policy self origin from the element's
Document, then explicitly enforces that policy into its relevant settings
object's container. Those settings dynamically read their actual Window's
current associated Document. This differs from Source Meta referrer,
SourceSnapshot policy cloning and Document CSP initialization, which read the
Document's own container directly. Current Meta CSP routing is preserved.

`html/meta_csp_settings_reassociation_test.v` uses two real Page-created
Documents, their Windows and actual response containers. After original Window
reassociation, an original-Document Meta appends once after the replacement's
header policy; the original container remains unchanged. Its real opaque self
origin still comes from the original element Document and survives actual
settings/Fetch projection. Source's removed directives stay filtered and a
content mutation or removal does not append or undo a policy. Actual adoption
and insertion into the replacement append a new Meta policy with the current
element Document's tuple origin and port. Restoring the Window selects the
original untouched container again. The own-Document initialization projection
also stays independent, using the separately translated initialization slice.

An earlier investigation incorrectly suggested replacing Meta CSP's settings
owner with the Document owner. Re-reading pinned Source exposed the mistake
before any implementation change; this focused Source regression records the
correct distinction. Existing ordinary header/Meta ordering proofs remain
valid within their prior attached-owner scope.

The focused new case passed with default GC in 29.61 seconds
(`Build/audit-fixes/source-meta-csp-settings-reassociation-default.log`). The
final GC-none five-file batch passed in 191.09 seconds
(`source-document-initialization-meta-settings-gc-none.log`), including this
case, own-Document initialization, prior inline ownership, Meta lifecycle and
typed-origin projection. No new Meta CSP implementation change was required.

Shared serialized CSP materialization,
standalone compatibility strings, reporting/GC/realm graphs and response
parser boundaries remain explicit in the prior feature documents.
