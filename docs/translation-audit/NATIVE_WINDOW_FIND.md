# Native Window.find exposure

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Window.idl:75`, `HTML/Window.cpp:2344–2365`, and the
previously translated `Page` / rendered-document find path. Feature commit:
`99e7bba7`.

The native compact browser now exposes `Window.find` and delegates each call to
the receiver's actual `html.WindowModel.find()`. That method uses the existing
owning `Page` search implementation. The binding does not implement a separate
JavaScript text search: matches come from actual rendered layout and select an
actual DOM `Range` in the owning document.

The pinned IDL has one optional `DOMString` parameter with an empty default.
Missing and undefined arguments therefore return false; null and numbers use
DOMString conversion, and additional arguments are ignored. Receiver validation
precedes argument conversion. Original JavaScript coercion exceptions propagate,
including the original thrown object, and Symbols produce a TypeError. The
public operation is a genuine, nonconstructible JavaScript function named
`find`, with length zero and a writable, enumerable, configurable property.

The source algorithm remains in the existing translation: an empty query fails,
an identical previous query advances to the next match, and a new query searches
case-insensitively without wrapping or clearing selection when no match exists.
The genuine native global is registered with the existing EventTarget owner
map, so replacing author-visible `globalThis` cannot redirect the owning Window.

Before a search, the compact transport replays pending DOM-facade mutations,
including argument-coercion side effects, into the actual document. Installing
the existing document layout hook lets the source rendered search update layout
even when author code calls `find()` before the browser's first normal layout.
Replay retains console messages for the normal end-of-script drain.

## Verification

`main_window_find_binding_test.v` contains four native regressions covering:

- Hidden, style, and script text exclusion; case-insensitive repeated matches;
  exhaustion and missing queries preserving the last actual Range, with client
  rectangles derived from rendered layout.
- Argument coercion that changes display and text before the search, while
  preserving a single console message.
- Operation metadata and descriptors, optional defaults, null and number
  conversion, ignored extra arguments, receiver-check ordering, original thrown
  values, and Symbol rejection.
- Two independent Pages, replacement of `globalThis`, and a supplementary
  Unicode character with correct UTF-16 Range offsets in the owning document.

Final focused runs passed with default GC and `-gc none` using
`v -old-compiler -enable-globals`. Their logs are
`Build/audit-fixes/source-native-window-find-operation-final-default.log` and
`Build/audit-fixes/source-native-window-find-operation-final-gc-none.log`.
The GC-none batch containing `main_test.v`,
`main_document_window_events_test.v`, and the find regressions passed 3/3:
`Build/audit-fixes/source-native-window-find-final-gc-none.log`.
The existing typed rendered-search regressions in `layout/window_find_test.v`
also passed during the initial GC-none run.

## Remaining boundaries

This completes the actual native `Window.find` exposure missing from DN-18; it
does not complete the Window/WindowProxy binding graph. The compact bridge
places the method on its actual global facade, matching the Source
`Meta/Generators/libweb_bindings/global_mixins.py:110–121` regular-operation
initializer. The complete generated WindowPrototype/WindowProxy graph remains
incomplete. Its JavaScript `getSelection()` facade also does not yet read back the
actual Range selected by the native search. The actual document's selection and
rendered geometry are updated correctly and checked directly.

DOMString transport still uses the repository's UTF-8 compatibility strings;
the supplementary-character case is covered, but full upstream UTF-16 storage,
including isolated surrogates, remains incomplete. The public operation uses a
captured JavaScript wrapper around the native host transport, rather than a
translated LibJS built-in-function record. The browser continues to use
JavaScriptCore, and this slice makes no claim of full LibJS runtime parity.
