module layout

// VOX_INCREMENTAL_LAYOUT_DIAGNOSTICS: why a change found no relayout root.
// Lists the change's depth, how many of its ancestors an intrinsic
// measurement sized, the outermost such ancestor and its parent, and the
// nearest recorded unmeasured ancestor (which the measured ones above it
// disqualify).
fn report_missing_relayout_root(previous &LayoutState, origin &Node) {
	if !incremental_layout_diagnostics { return }
	mut depth := 0
	mut flagged := 0
	mut outermost := ?&Node(none)
	mut outermost_depth := 0
	mut recorded := ?&Node(none)
	mut recorded_depth := 0
	mut ancestor := origin.parent()
	for ancestor != none {
		current := ancestor or { break }
		depth++
		if current.sized_by_ancestor_measurement_ {
			flagged++
			outermost = current
			outermost_depth = depth
		} else if recorded == none {
			if styled := current.as_node_with_style() {
				if record := previous.relayout_records_[styled.layout_index()] {
					if voidptr(record.node) == voidptr(current) && previous.try_get(styled) != none {
						recorded = current
						recorded_depth = depth
					}
				}
			}
		}
		ancestor = current.parent()
	}
	mut outer := '-'
	if node := outermost {
		parent_display := if parent := node.parent() { parent.display().str() } else { '-' }
		outer = '${layout_debug_tag(node)}@${outermost_depth} display=${node.display()} parent=${parent_display}'
	}
	recorded_text := if node := recorded { '${layout_debug_tag(node)}@${recorded_depth}' } else { '-' }
	eprintln('VOX_RELAYOUT_ROOT none origin=${layout_debug_tag(origin)} depth=${depth} measured=${flagged} outermost=${outer} recorded=${recorded_text}')
}
