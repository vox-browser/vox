# MediaSource URL authorization through the actual node document

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `a0f60763`, following the
[owned DOM URL record](BLOB_URL_DOM_RECORD_OWNER.md) and
[actual Fetch Environment caller](BLOB_URL_FETCH_ACTUAL_REQUEST.md).

Source `HTML/HTMLMediaElement.cpp:1257–1297` first authorizes the copied URL
entry with the actual node Document's relevant settings. Self-fetch uses
those settings' creation URL and the global Window's current navigable with
no logical parent. It does not substitute Document URL or cached local
browsing-context flags. Authorization failure and a Blob tag fall through
to remote fetching. Only an authorized MediaSource tag resolves the live
store entry and attaches its actual object.

The V media caller now follows that sequence. It obtains settings from its
associated DOM element's own Document, uses the existing actual-owner
partition algorithm and current Window/navigable query, then resolves the
native store only for the MediaSource tag. The stable handle and attachment
callback lead to the genuine MediaSource object; no ID-only descriptor or
fabricated settings record is supplied. Store-object kind and live-entry
requirements retain explicit fatal checks, following Source's value/variant
accesses. An authorized retained tag whose entry was removed still requires
that live entry; no separate death-case proof is claimed. Standalone string
consumers retain their Legacy store behavior.

## Focused verification

After the duplicate import diagnostic was corrected, the original test
executed and failed at the actual media caller with `No media fetch hook`.
The genuine store entry had fallen through because the old implementation
only checked the separate Legacy store.

The final four cases create actual Page, Document, Window/settings, DOM video,
media model and MediaSource objects. They cover:

- Opaque-origin selection through the real resource parser, attachment/detach,
  fragment resolution to the same live object and rejection of the genuine
  MediaSource tag by Blob scheme Fetch.
- Document origin changes after parsing: the old copied entry is denied and
  reaches the remote hook; a fresh parse copies the new creator origin and
  attaches the same still-live source.
- Document URL alone does not select self-fetch. Settings creation URL and
  the actual logical parent control the bypass even when local browsing
  context state disagrees.
- An actual Blob tag reaches the remote hook with its owned URL entry intact.

| Run | Result | Seconds |
| --- | --- | ---: |
| Initial shared import diagnostic, GC-none | Compiler failure | 146.260 |
| Original attachment caller, GC-none | Executed missing-fetch-hook failure | 230.583 |
| Final Fetch/media callers, default GC | 2/2 PASS | 256.504 |
| Final callers/MediaSource/settings/main, GC-none | 5/5 PASS | 743.454 |

The original attachment run used the unchanged media implementation and the
concurrent, corrected Fetch prerequisite; its exact file/probe hashes are
retained. The final batch includes both new owner files, existing MediaSource
and store/settings tests, and the 66-case main browser regression. Final
commands use `VJOBS=2 v -old-compiler -enable-globals test`, adding `-gc none`
for that row. [Fetch evidence](BLOB_URL_FETCH_ACTUAL_REQUEST.md) lists all
files and the other retained compiler/fixture diagnostics.

Both implementation/test files match the saved media feature record. Full
argv, Source pin, original probes, combined feature and log hashes and
summaries are in `Build/audit-fixes/source-blob-callers-manifest.json`, SHA256
`2cb126a1cb529dfba79000eb282a8b33c972d95e8ea86e0613577cc8ab5b36d0`.
Logs use `source-blob-media-` and `source-blob-callers-` prefixes.

This completes the bounded URL-provider authorization and attachment caller.
Remote media transport/demux, native public URL/MSE WebIDL exposure and
physical GC/WrapperWorld lifetime equivalence remain separate. No new full
package, production bundle or screenshot proof is claimed. The ledger remains
**32 fixed / 25 partial / 9 open**.
