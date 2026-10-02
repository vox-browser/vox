# Navigation interception source slice

This implements DN-02's interception commit and asynchronous completion for push, replace, and reload on the Navigation record owned by an actual Window. It does not close DN-02 in full.

The reference checkout is Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`. The translated control flow comes from `HTML/Navigation.cpp:45–50` (handler invocation and Promise Resolve), `805–854` (abort), `971–1072` (commit-handler completion), `1260–1394` (intercept commit and firing result), and `1633–1673` (same-document entry update tail), plus `HTML/NavigateEvent.{h,cpp}`'s handler list and started flag. Actual URL/history commits reuse the existing `perform_url_and_history_update_steps()` translation of `HTML/LocalNavigable.cpp:4246–4312`.

## Implemented behavior

The native interception path sets the event's committed state, creates the transition in the owning Window's realm, and commits through that Window's actual Navigable and session-history records. Push and replace call the URL/history update steps; reload uses the active session-history entry. Intercepted firing returns false, preventing the existing caller from adding another entry or finishing the navigation synchronously.

Same-document entry updates capture the event and tracker before dispatching `currententrychange` and `dispose`. The source identity and started-flag checks launch commit-handler steps once after these events, with the source fallback retained for an entry update that did not start them. Temporary execution contexts preserve the source callback and microtask boundaries.

Handlers are stored as Promise-returning WebIDL callback records. Their results are adopted into capabilities that use the actual Window realm and document microtask queue. Completion waits for every handler. A zero-handler interception still installs a resolved-undefined input, preserving the source reaction timing. Success and failure check the relevant Window's current document activity, the actual abort signal, and ongoing-event identity before changing state.

Failure and abort retain the original WebIDL/DOM JavaScript value. The tracker, transition, and actual `ErrorEvent.error` receive that same value. Error information is extracted in source order through the existing owning-realm extraction hook. Supersession uses an actual retained `AbortError` DOMException record. Native navigation, entry-change, dispose, success, error, and abort-signal events use the owning global's relative high-resolution timestamp.

The transition's committed promise follows the pinned source: both transition promises are marked handled, but successful interception only resolves the transition's finished promise. This slice does not add a committed resolution absent from that source. Completion also accesses the current transition after dispatching the success/error event, preserving the source's reentrancy order.

## Verification

`html/navigation_interception_test.v` has nine cases using real Window, Navigable, and session-history ownership: actual push/replace commits, pending completion, retained DOMException rejection, supersession, activity gating, reentrant entry-change navigation, zero-handler reaction ordering after dispose, synchronous callback rejection and error information, reload, and multiple pending handlers. The fixture invokes the source initializer on the actual Navigable's existing entries; it does not create a replacement history store.

`browserjs/navigation_interception_test.v` has two integration cases using the existing actual JavaScriptCore callback/Promise adapter: a pending author thenable and an actual author Promise rejected with an object. Rejection identity is checked through the tracker, transition, and native ErrorEvent. These tests invoke the typed Navigation algorithm with real engine callbacks; they do not expose a substitute JavaScript Navigation object.

The nine source cases and two JavaScriptCore cases pass with default GC and `-gc none`. The existing six Navigation cases and four NavigateEvent cases pass with `-gc none`. Validation uses the repository's old compiler and enabled globals, with the existing native Skia/ICU link dependencies. No native application rebuild or screenshot workflow was run for this private slice.

## Remaining boundaries

- Intercepted traversal still uses the preexisting adapter. The pinned source requests an asynchronous `ResumeTraverseHistoryOperationParameters` operation from the Page's HistoryExecutor, with abort and ongoing-event identity checks before resuming. That executor/request graph is not available in the translated HTML navigation implementation and is not replaced here with direct traversal.
- Ordinary navigation retains its existing adapter, including its direct entry construction/completion. Full public `navigate()`/reload/traverse dispatch, cross-document fetch and commit, and HistoryExecutor/UI-process synchronization require their source graph separately.
- Public compact JavaScript bindings for Navigation, NavigateEvent interception, NavigationHistoryEntry, and NavigationTransition remain absent. The actual callback adapter is verified as a prerequisite; this slice does not claim a browser-visible Navigation API.
- Production entry-list initialization must call the source initializer with the actual navigation-created session-history entries. The focused fixtures do this explicitly; empty or synthetic entry initialization is not added.
- Error information consumes the existing owning-realm extraction hook. Full native engine error-object/traceback extraction remains a separate runtime boundary; original thrown/rejected value identity is already preserved.
- The old `fn () !` handler option and fully-active override remain explicit standalone V compatibility adapters. Native Window interception uses callback records and real document activity.
