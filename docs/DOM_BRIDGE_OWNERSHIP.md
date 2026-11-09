# Native DOM authority and compact wrappers

The native DOM owns element attributes, attribute identity, mutation records,
custom-element reactions, and the document associated with an attribute. The
compact JavaScript facade owns wrapper identity and WebIDL argument conversion.
An attribute read must not return a value from `__state.elements`.

## Attribute API boundary

`compact/native_attributes.v` defines one typed native query family for
`getAttribute`, `hasAttribute`, their namespace variants, attribute names,
removal, toggling, `Attr`, and `NamedNodeMap`. Reflected common properties use
that family too. Setters preserve the native Trusted Types path and concrete
HTML model mutation hooks.

`NamedNodeMap` is a live view of the native element. `Attr` wrappers are keyed
by opaque handles to native attribute allocations, rather than namespace/name
pairs. Removing an attribute and recreating the same name produces a new
wrapper; a retained removed wrapper keeps the detached attribute's last value.
Attaching it to another element preserves that attribute's identity. Native
`Attr.document()` follows the attached element's document and records that
document when the attribute is detached or replaced.

The realm's handle registry retains the storage of attributes it exposes.
Cross-document attribute attachment uses the same balanced storage relationship
as node adoption. The registry's owning document and its retained storage are
retired through the existing realm/document lifecycle; there is no permanent
pin flag for attributes.

## Mutation visibility

Remaining batched API families share one pending-state contract:

1. `__compactTakePendingDOMState` serializes and detaches one pending batch.
   Queries omit console output and canvas transport; native host and task
   boundaries can include native canvas state. Serialization failure does not
   consume the batch.
2. `replay_compact_dom_snapshot` applies that batch to native owners and records
   rendering effects. Query, host, and task paths use this implementation.
3. `settle_compact_dom_reactions` delivers queued custom-element reactions and
   replays any new batch produced by those reactions before the next native
   read or task paint. A callback entered during native replay writes into a
   new batch; completing the earlier batch cannot clear it.
4. `flush_compact_dom_mutations` is the synchronous boundary for native host
   APIs. Replay failures reject the operation. Console output and navigation
   remain available to the task owner.
5. `commit_compact_dom_task` and `apply_compact_dom_task` collect task output
   after reactions settle. A navigation written by a reaction supersedes an
   earlier navigation, and its logs are collected before the realm can retire.
   Clearing console output never clears DOM mutations.

The `flushDOM` query is an explicit synchronization operation. Bindings do not
need a dummy selector or a `readyState` read to publish preceding writes. Cache
fast paths use `__compactHasPendingDOMState`; a native version alone is
insufficient while JavaScript has an unpublished batch.

The handoff preserves order without transactional rollback. Once native replay
has accepted a batch, failure of the requested operation does not requeue the
already applied writes. This contract concerns reentry from native replay;
author-defined serialization hooks are not a general transaction mechanism.

## Layout projection contract

The typed layout tree and `LayoutState` own layout geometry. DOM `LayoutNode`
values are read-only projections of a committed attachment. A lazy visual-line
provider captures that attachment's exact `LayoutState`, rather than resolving
the viewport's latest state when a consumer first reads it. Copies of an
unmaterialized projection therefore keep their original geometry across a
relayout that reuses the typed tree.

The provider is shared per attachment and allocated outside geometry scratch;
it does not enlarge the per-node `LayoutNode` record. A projection copy does
not independently retain document storage and is not a snapshot of arbitrary
future text or DOM mutations. Consumers must keep the document's storage alive.

## Continuing the migration

`__state` still contains compatibility records and pending writes for API
families that have not migrated. New native families should reuse the query
and host boundaries above, keep language-level identity in wrappers, and avoid
introducing another semantic cache. A cache needed for a read must identify
its native version and check the shared pending-state predicate.

The focused Linux gate executes native attribute identity, facade behavior,
reaction/flush ordering, and lazy geometry tests in both Boehm and production
`prealloc` configurations. The corresponding tests are
`compact/native_attributes_test.v`, `compact/mutation_boundary_test.v`,
`dom/native_attribute_identity_test.v`, and
`layout/lazy_dom_visual_lines_test.v`.
