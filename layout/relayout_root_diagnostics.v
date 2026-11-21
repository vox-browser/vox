module layout

import platform

// Why intrinsic sizing marked a box as sized by an ancestor's measurement
// (incremental_layout.v), kept for VOX_INCREMENTAL_LAYOUT_DIAGNOSTICS only.
enum MeasurementMark as u8 {
	none_
	min_content_width
	max_content_width
	content_width
	column_flex_width
	flex_width
	min_content_height
	max_content_height
	content_height
	measurement_layout
}

__global measurement_mark_reasons map[u64]MeasurementMark
// Every node noted as a layout invalidation origin since the committed pass
// `relayout_origin_census_state`, without the 64-origin limit.
__global relayout_origin_census []voidptr
__global relayout_origin_census_state voidptr

fn note_measurement_mark(node &Node, reason MeasurementMark) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	measurement_mark_reasons[u64(voidptr(node))] = reason
}

fn note_relayout_origin_for_census(state &LayoutState, node &Node) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if relayout_origin_census_state != voidptr(state) {
		relayout_origin_census = []voidptr{}
		relayout_origin_census_state = voidptr(state)
	}
	if voidptr(node) in relayout_origin_census { return }
	relayout_origin_census << voidptr(node)
}

fn relayout_census_tag(node &Node) string {
	mut tag := layout_debug_tag(node)
	if dom_node := node.dom_node() {
		if element := dom_node.as_element() {
			class := element.get_attribute_value('class').all_before(' ')
			if class != '' { tag += '.' + class.limit(24) }
		}
	}
	return tag
}

// The ancestors that decide the relayout root: measured ones with their
// reason (M:...), recorded unmeasured ones (R), up to the root element.
fn relayout_census_chain(previous &LayoutState, origin &Node) string {
	mut parts := []string{}
	mut ancestor := origin.parent()
	for ancestor != none {
		current := ancestor or { break }
		if current.is_viewport() { break }
		mut mark := ''
		if current.sized_by_ancestor_measurement_ {
			mark = '[M:${measurement_mark_reasons[u64(voidptr(current))]}]'
		} else if styled := current.as_node_with_style() {
			if record := previous.relayout_records_[styled.layout_index()] {
				if voidptr(record.node) == voidptr(current) { mark = '[R]' }
			}
		}
		if mark != '' || parts.len < 2 { parts << relayout_census_tag(current) + mark }
		ancestor = current.parent()
	}
	return parts.join(' < ')
}

// VOX_INCREMENTAL_LAYOUT_DIAGNOSTICS: before each incremental attempt, every
// origin since the committed pass: detached from the current tree, without a
// relayout root (grouped by origin and deciding ancestors) or with one.
fn report_relayout_origin_census(previous &LayoutState, root &Node) {
	if !incremental_layout_diagnostics { return }
	if relayout_origin_census_state != voidptr(previous) {
		eprintln('VOX_RELAYOUT_ORIGINS total=0')
		return
	}
	mut detached := 0
	mut rooted := 0
	mut roots := map[u64]bool{}
	mut rootless := map[string]int{}
	for pointer in relayout_origin_census {
		node := unsafe { &Node(pointer) }
		if voidptr(node.root()) != voidptr(root) {
			detached++
			continue
		}
		if relayout_root := incremental_relayout_root_above(previous, node) {
			rooted++
			roots[u64(voidptr(relayout_root))] = true
		} else {
			rootless['${relayout_census_tag(node)} < ${relayout_census_chain(previous, node)}']++
		}
	}
	mut rootless_count := 0
	for _, count in rootless { rootless_count += count }
	eprintln('VOX_RELAYOUT_ORIGINS total=${relayout_origin_census.len} detached=${detached} rootless=${rootless_count} rooted=${rooted} roots=${roots.len} unbounded=${previous.layout_invalidation_unbounded_}')
	mut keys := rootless.keys()
	keys.sort_with_compare(fn [rootless] (a &string, b &string) int {
		return rootless[*b] - rootless[*a]
	})
	for key in keys#[..8] {
		eprintln('VOX_RELAYOUT_ROOTLESS ${rootless[key]} ${key.limit(400)}')
	}
	relayout_origin_census = []voidptr{}
	relayout_origin_census_state = unsafe { nil }
}

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
		outer = '${layout_debug_tag(node)}@${outermost_depth} parent=${parent_display.all_before("{")}'
	}
	recorded_text := if node := recorded { '${layout_debug_tag(node)}@${recorded_depth}' } else { '-' }
	eprintln('VOX_RELAYOUT_ROOT none origin=${layout_debug_tag(origin)} depth=${depth} measured=${flagged} outermost=${outer} recorded=${recorded_text}')
}
