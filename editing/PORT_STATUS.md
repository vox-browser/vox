# Editing module V translation

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Editing`

Audited: 2026-09-26

The editing algorithms run directly on the translated DOM, as upstream does.
`execCommand()`, the `queryCommand*()` methods, the command definitions, and
the Internal/Algorithms steps read and mutate live `dom.Node` trees, resolve
style through the translated `CSSStyleProperties`, and record every mutation
through the `EditCommand` proxies so each command is one undoable history step.
DOM owns the IDL entry points; because `dom` cannot import `editing`,
`dom_bridge.v` installs `DocumentEditingCommandHook` callbacks that forward
them here.

| Upstream implementation unit | V implementation |
| --- | --- |
| `ClipboardSanitizer.cpp` | `clipboard_sanitizer.v` |
| `ClipboardSerializer.cpp` | `clipboard_serializer.v` |
| `CommandNames.cpp` | `command_names.v` |
| `Commands.cpp` | `commands.v` |
| `EditCommand.cpp` | `edit_command.v` |
| `EditingHistory.cpp` | `editing_history.v` |
| `ExecCommand.cpp` | `exec_command.v`, `dom_bridge.v` |
| `InlineInsertion.cpp` | `inline_insertion.v` |
| `InsertedContent.cpp` | `inserted_content.v` |
| `InsertedNodes.cpp` | `inserted_nodes.v` |
| `InterchangeWhitespace.cpp` | `interchange_whitespace.v` |
| `Internal/Algorithms.cpp` | `internal_algorithms.v`, `internal_algorithms_values.v`, `internal_algorithms_structure.v`, `internal_algorithms_deletion.v`, `dom_editing_operations.v` |
| `LegacyFontStyle.cpp` | `legacy_font_style.v` |
| `MutationTrackedRange.cpp` | `mutation_tracked_range.v` |
| `ParagraphIntegration.cpp` | `paragraph_integration.v` |
| `ParagraphOperations.cpp` | `paragraph_operations.v` |
| `ParagraphTransfer.cpp` | `paragraph_transfer.v` |
| `ReplaceSelection.cpp` | `replace_selection.v`, `block_replacement_plan.v` |
| `ReplacementEndpoints.cpp` | `replacement_endpoints.v` |
| `ReplacementFragment.cpp` | `replacement_fragment.v` |
| `ReplacementRangeCleanup.cpp` | `replacement_range_cleanup.v` |
| `ReplacementStyleCleanup.cpp` | `replacement_style_cleanup.v` |
| `StyledMarkupAccumulator.cpp` | `styled_markup_accumulator.v` |
| `StyledMarkupSelection.cpp` | `styled_markup_selection.v` |
| `StyledMarkupSerializer.cpp` | `styled_markup_serializer.v` |
| `VisiblePosition.cpp` | `visible_position.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Editing/` | 26 | 12,720 | 13,918 | 226 + 2,130 in `html/` | Complete |

The command registry has all 41 upstream command names and the 38 command
definitions, including `undo`, `redo`, and the actionless
`preserveWhitespace`. Definitions carry their action, state, value, and
indeterminate callbacks, relevant CSS property, inline activated values,
override preservation, and mapped input type. State and value queries read
resolved style, so `queryCommandValue('foreColor')` returns the resolved color
and `queryCommandState('bold')` reflects existing markup. `backColor` and
`hiliteColor` share one value override. `insertHTML` passes its value through
the Trusted Types `Document execCommand` sink before replacing the selection.
Font element presentational hints (`color`, `size`, `face`) feed the
effective-command-value algorithm, and legacy font sizes map to CSS
absolute-size keywords through the style computer's size table.

Copy serializes through the styled-markup units: `StyledMarkupSelection`
derives the serialization range and interchange-newline boundaries from visible
positions, `StyledMarkupAccumulator` clones the rendered selected subtrees, and
`StyledMarkupSerializer` removes unrendered text, restores list structure,
places interchange markers, flattens lone transport wrappers, and protects
collapsible whitespace.

Paste goes through the same `insertHTML` path, so pasted content is recorded
and undoable. Paste-pipeline helpers (legacy font materialization, paragraph
splitting and transfer, text-node coalescing, style cleanup) mutate through the
recording proxies. Detached staging nodes are prepared inside a proxy-mutation
scope, as upstream does.

## Known gaps

- Upstream `update_selection_style_observability()` is not ported. Document
  keeps the `running_editing_command_action` flag it consumes, but the CSS
  feature it drives is not present in the V CSS module.

## Verification

```text
$ v -enable-globals test editing html/exec_command_test.v html/editing_bridge_test.v ...
Summary for all V _test.v files: 31 passed, 31 total.
```
