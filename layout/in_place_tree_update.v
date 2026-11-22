module layout

import css
import dom
import os
import platform

// In-place layout tree update. A layout tree update flags the DOM node whose
// child list needs new boxes (a node gaining or losing children, or a child
// whose style needs another box), and every ancestor carries the descendant
// flag. The builder used to construct the whole tree again from a new
// viewport: every ancestor of a change got a new box, so the root changed, the
// incremental relayout could not run and the following pass laid out the
// document again from the top, restoring what it could.
//
// For a flagged element whose box is an ordinary block, flex or grid
// container with only block-level children, keep that box and its ancestors
// and update its child list in place: keep each child box whose element is
// unchanged, build new boxes for new or restyled children and drop the boxes
// of removed ones. The parent box is then marked for layout, which records it
// as an origin of the incremental relayout. Any branch outside that subset
// keeps the complete builder for the whole update.
//
// New boxes take layout indexes past those of the committed tree, so the
// committed values and relayout records of kept boxes stay under their
// indexes. Counters and quotes are resolved by the builder in tree order; an
// update whose new or removed boxes involve list items, counter operations or
// counter and quote content keeps the complete builder, so no other element's
// counters change.

// Same-binary control: every layout tree update builds the tree again.
const disable_in_place_tree_update = os.getenv('VOX_DISABLE_IN_PLACE_TREE_UPDATE') != ''
const in_place_tree_update_diagnostics = os.getenv('VOX_IN_PLACE_TREE_UPDATE_DIAGNOSTICS') != ''
// Same-binary control: a flagged element whose own child list cannot be
// updated in place declines the update instead of being rebuilt by its parent.
const disable_in_place_escalation = os.getenv('VOX_DISABLE_IN_PLACE_ESCALATION') != ''
// Same-binary control: subtrees containing tables keep the complete builder.
const disable_in_place_tables = os.getenv('VOX_DISABLE_IN_PLACE_TABLES') != ''
// Same-binary control: a kept box built from state that changed without a
// flag declines the update instead of being rebuilt by its parent.
const disable_in_place_stale_rebuilds = os.getenv('VOX_DISABLE_IN_PLACE_STALE_REBUILDS') != ''

__global in_place_tree_update_counts [2]u64
// VOX_IN_PLACE_TREE_UPDATE_DIAGNOSTICS: boxes built by in-place updates, by
// why their element's previous box was not kept ('new' when it had none).
__global in_place_built_box_counts map[string]u64
// Tests of the complete builder's reuse paths suspend in-place updates so that
// their tree updates reach it.
__global in_place_tree_update_suspended bool

// Layout tree updates made in place and declined, in this process.
pub fn in_place_tree_update_statistics() (u64, u64) {
	return in_place_tree_update_counts[0], in_place_tree_update_counts[1]
}

// One flagged element's box with its new child list.
struct InPlaceChildList {
	parent   &Node
	computed &css.ComputedProperties
	children []&Node
	removed  []&Node
	// The parent's anonymous blocks around inline runs, made again.
	wrappers []&Node
	added    []&Node
	// Elements in the child list without a box now.
	unrendered []&dom.Element
}

struct InPlaceTreeUpdate {
mut:
	document       &dom.Document
	style_computer &css.StyleComputer
	root           &Node
	builder        TreeBuilderState
	lists          []InPlaceChildList
	reason         string
	// The flagged element being planned, for diagnostics.
	planning       &dom.Element = unsafe { nil }
	// Whether some generated box of the kept tree shows counter or quote
	// values, which list items and counter operations elsewhere change.
	counter_content bool
	// Children rebuilt by their parent's list because their own list could
	// not be updated in place, by DOM node.
	forced map[u64]bool
	// Elements whose kept boxes were built from state that has changed.
	stale []&dom.Node
}

enum InPlacePlan {
	planned
	declined
	// The branch's flagged element cannot keep its box; its parent's list
	// should rebuild it.
	escalate
}

// The element whose child list an in-place update re-syncs: its style and
// its box, or why its box cannot keep a re-synced list.
struct InPlaceListParent {
	element  &dom.Element            = unsafe { nil }
	computed &css.ComputedProperties = unsafe { nil }
	box      &Node                   = unsafe { nil }
	reason   string
}

// Reasons local to the element's own box: its parent's list can rebuild it.
const in_place_escalatable_reasons = ['not-element', 'element', 'parent-display', 'first-letter',
	'parent-box', 'parent-kind']

fn (mut update InPlaceTreeUpdate) decline(reason string) bool {
	if update.reason == '' {
		update.reason = reason
		if in_place_tree_update_diagnostics && update.planning != unsafe { nil } {
			update.reason += ' parent=${update.planning.local_name()}.${update.planning.get_attribute_value('class').limit(40)}'
		}
	}
	return false
}

// The committed tree's root after updating every flagged branch in place, or
// none when the complete builder is needed. Planning builds new boxes without
// attaching them; the committed tree changes only once every branch qualifies.
fn update_layout_tree_in_place(document &dom.Document, mut style_computer css.StyleComputer) ?&Node {
	if disable_in_place_tree_update || in_place_tree_update_suspended {
		return none
	}
	// Requests for the complete builder are not declines: the update is not
	// attempted.
	if document.needs_full_layout_tree_update() {
		return skip_in_place_tree_update('full-tree-update')
	}
	previous := document_layout_result(document) or { return none }
	if previous.root == unsafe { nil } || previous.state == unsafe { nil } { return none }
	document_node := document.as_node()
	if document_node.needs_layout_tree_update_() {
		return skip_in_place_tree_update('document-node')
	}
	if document.top_layer_elements_for_layout().len > 0 {
		return skip_in_place_tree_update('top-layer')
	}
	root_element := document.document_element() or { return none }
	mut update := InPlaceTreeUpdate{
		document:       document
		style_computer: style_computer
		root:           previous.root
		builder:        new_tree_builder_state()
	}
	defer { update.builder.finish() }
	// New boxes are built without reusing committed boxes: a box taken from
	// elsewhere in the kept tree would keep its old parent there.
	update.builder.allow_subtree_reuse = false
	root_node := root_element.as_node()
	if root_node.needs_layout_tree_update_() {
		return decline_in_place_tree_update('root-element')
	}
	if !update.tree_state_is_current(previous.root) {
		return decline_in_place_tree_update(update.reason)
	}
	for stale in update.stale {
		mut flagged := unsafe { &dom.Node(stale) }
		flagged.set_needs_layout_tree_update(true, .none)
	}
	match update.plan_branch(root_node) {
		.planned {}
		.declined { return decline_in_place_tree_update(update.reason) }
		.escalate { return decline_in_place_tree_update('root-escalation') }
	}
	// With no list to update (every flag inside unrendered subtrees), the
	// committed tree is already current.
	if update.lists.len > 0 {
		update.apply(previous)
	}
	in_place_tree_update_counts[0]++
	if in_place_tree_update_diagnostics {
		mut added := 0
		mut removed := 0
		for list in update.lists {
			added += list.added.len
			removed += list.removed.len
		}
		eprintln('VOX_IN_PLACE_TREE_UPDATE updated parents=${update.lists.len} added=${added} removed=${removed} built_boxes=${in_place_built_box_counts}')
	}
	return previous.root
}

fn skip_in_place_tree_update(reason string) ?&Node {
	if in_place_tree_update_diagnostics {
		eprintln('VOX_IN_PLACE_TREE_UPDATE skipped=${reason}')
	}
	return none
}

fn decline_in_place_tree_update(reason string) ?&Node {
	in_place_tree_update_counts[1]++
	if in_place_tree_update_diagnostics {
		eprintln('VOX_IN_PLACE_TREE_UPDATE declined=${reason}')
	}
	return none
}

// Follow the descendant flags below `node`, planning each flagged element.
fn (mut update InPlaceTreeUpdate) plan_branch(node &dom.Node) InPlacePlan {
	// Nothing below an element that is not rendered and had no box has a box
	// to keep or replace (an element that had one is planned by its parent).
	if element := node.as_element() {
		if in_place_element_is_unrendered(element) { return .planned }
	}
	if node.needs_layout_tree_update_() {
		target := update.child_list_parent(node)
		if !disable_in_place_escalation && target.reason in in_place_escalatable_reasons {
			return .escalate
		}
		return if update.plan_child_list(node) { .planned } else { .declined }
	}
	if !node.child_needs_layout_tree_update_() { return .planned }
	if element := node.as_element() {
		if element.shadow_root() != none {
			update.decline('shadow-host')
			return .declined
		}
	}
	mark := update.lists.len
	for child in node.children {
		if child.needs_layout_tree_update_() || child.child_needs_layout_tree_update_() {
			match update.plan_branch(child) {
				.planned {}
				.declined { return .declined }
				.escalate {
					// Rebuild the child in this node's list instead; the lists
					// planned below this node are planned again there.
					update.lists.trim(mark)
					update.forced[u64(voidptr(child))] = true
					target := update.child_list_parent(node)
					if target.reason in in_place_escalatable_reasons { return .escalate }
					return if update.plan_child_list(node) { .planned } else { .declined }
				}
			}
		}
	}
	return .planned
}

fn (update &InPlaceTreeUpdate) child_list_parent(node &dom.Node) InPlaceListParent {
	element := node.as_element() or { return InPlaceListParent{ reason: 'not-element' } }
	if !element.is_html_element() || element.shadow_root() != none
		|| element.local_name() in in_place_special_parents {
		return InPlaceListParent{ element: element, reason: 'element' }
	}
	if element.rendered_in_top_layer() { return InPlaceListParent{ element: element, reason: 'top-layer' } }
	computed := css.computed_properties_for_element(element) or {
		return InPlaceListParent{ element: element, reason: 'unstyled' }
	}
	if !in_place_parent_display_is_supported(computed.display()) {
		return InPlaceListParent{ element: element, reason: 'parent-display' }
	}
	if first_letter := css.computed_properties_for_pseudo_element(element, .first_letter) {
		if !first_letter.display().is_none() {
			return InPlaceListParent{ element: element, reason: 'first-letter' }
		}
	}
	parent := in_place_box_of(node) or { return InPlaceListParent{ element: element, reason: 'parent-box' } }
	container := parent.is_block_container() || computed.display().is_flex_inside()
		|| computed.display().is_grid_inside()
	if parent.is_anonymous() || parent.is_list_item_box() || parent.is_table_wrapper()
		|| parent.is_replaced_box() || parent.is_svg_box() || parent.is_fieldset_box() || !container
		|| voidptr(parent.document()) != voidptr(update.document) {
		return InPlaceListParent{ element: element, reason: 'parent-kind' }
	}
	if voidptr(parent.root()) != voidptr(update.root) {
		return InPlaceListParent{ element: element, reason: 'detached-parent' }
	}
	return InPlaceListParent{ element: element, computed: computed, box: parent }
}

fn in_place_element_is_unrendered(element &dom.Element) bool {
	if in_place_box_of(element.as_node()) != none { return false }
	if element.as_node().unsafe_layout_node() != none { return false }
	computed := css.computed_properties_for_element(element) or { return true }
	return computed.display().is_none()
}

fn in_place_box_of(node &dom.Node) ?&Node {
	mirror := node.unsafe_layout_node() or { return none }
	if mirror.real_layout_handle() == unsafe { nil } || mirror.continuation_next() != none {
		return none
	}
	return unsafe { &Node(mirror.real_layout_handle()) }
}

fn in_place_parent_display_is_supported(display css.Display) bool {
	if display.is_none() || display.is_contents() || display.is_list_item() || !display.is_block_outside() {
		return false
	}
	return display.is_flow_inside() || display.is_flow_root_inside() || display.is_flex_inside()
		|| display.is_grid_inside()
}

// Whether `box` and its subtree may be added to or removed from a kept tree:
// nothing in it affects the counters, quotes, SVG resources or table structure
// of boxes outside it.
fn (mut update InPlaceTreeUpdate) subtree_is_self_contained(box &Node) bool {
	// Markers take their text from the item's ordinal during layout; counter
	// state only matters to generated content that shows it.
	if (box.is_list_item_box() || box.is_list_item_marker_box()) && update.counter_content {
		return update.decline('list-item')
	}
	if box.is_svg_svg_box() {
		return in_place_svg_is_closed(box) || update.decline('svg')
	}
	if box.is_svg_box() || is_svg_resource_box(box) { return update.decline('svg') }
	if disable_in_place_tables && (box.is_table_wrapper() || box.display().is_table_inside()
		|| box.display().is_internal_table()) {
		return update.decline('table')
	}
	if box.is_generated_for_pseudo_element() && generated_content_uses_document_state(box) {
		return update.decline('generated-content')
	}
	if styled := box.as_node_with_style() {
		values := unsafe { &css.ComputedValues(styled.computed_values()) }
		if update.counter_content && (values.counter_reset().len != 0
			|| values.counter_increment().len != 0 || values.counter_set().len != 0) {
			return update.decline('counter')
		}
	}
	for child in box.children() {
		if !update.subtree_is_self_contained(child) { return false }
	}
	return true
}

// Elements whose box gets internal children or wrappers from its own
// construction (controls, details, media, fieldsets and buttons).
const in_place_special_parents = ['button', 'fieldset', 'legend', 'input', 'textarea', 'select',
	'details', 'summary', 'audio', 'video', 'progress', 'meter', 'slot', 'template', 'iframe',
	'object', 'embed', 'canvas', 'img', 'marquee']

fn in_place_box_is_split(box &Node) bool {
	if metrics := box.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return true }
	}
	if dom_node := box.dom_node() {
		if mirror := dom_node.unsafe_layout_node() {
			if mirror.continuation_next() != none { return true }
		}
	}
	return false
}

// Whether an inline box contains in-flow block-level boxes, which the builder
// treats specially (continuations and hoisted generated boxes).
fn in_place_inline_contains_blocks(box &Node) bool {
	for child in box.children() {
		if !child.is_inline() && !child.is_out_of_flow() && child.as_node_with_style() != none {
			return true
		}
		// An atomic inline lays its block children out in its own context.
		if child.is_atomic_inline() { continue }
		if in_place_inline_contains_blocks(child) { return true }
	}
	return false
}

fn (mut update InPlaceTreeUpdate) plan_child_list(node &dom.Node) bool {
	target := update.child_list_parent(node)
	if target.element != unsafe { nil } { update.planning = target.element }
	if target.reason != '' { return update.decline(target.reason) }
	element := target.element
	computed := target.computed
	parent := target.box
	// The current child boxes: the parent's own generated boxes first and
	// last, one box per element child and per text child, the latter two
	// directly or inside the anonymous blocks wrapping inline runs.
	mut before := []&Node{}
	mut after := []&Node{}
	mut existing := map[u64]&Node{}
	mut texts := map[u64]&Node{}
	mut wrappers := []&Node{}
	mut current := []&Node{}
	for child in parent.children() {
		// A table element's box sits in an anonymous wrapper, which stands for
		// the table in the child list.
		if child.is_table_wrapper() {
			current << child
			continue
		}
		if child.is_anonymous() && !child.is_generated_for_pseudo_element() {
			if !child.children_are_inline() || !child.is_block_container() {
				return update.decline('anonymous-child')
			}
			wrappers << child
			current << child.children()
			continue
		}
		current << child
	}
	mut seen_content := false
	for child in current {
		// A generated box with display: table sits in its table wrapper (the
		// clearfix `::before { display: table }`).
		generated := in_place_generated_box(child)
		if generated.is_generated_for_pseudo_element() {
			if generator := generated.pseudo_element_generator() {
				if voidptr(generator) == voidptr(element) {
					if seen_content { after << child } else { before << child }
					continue
				}
			}
			return update.decline('foreign-generated-box')
		}
		seen_content = true
		if !update.note_existing_child(child, mut existing, mut texts) { return false }
	}
	mut children := before.clone()
	mut added := []&Node{}
	mut unrendered := []&dom.Element{}
	mut kept := map[u64]bool{}
	for child in node.children {
		key := u64(voidptr(child))
		if child.is_text() {
			// A flagged text node (its text became or stopped being white
			// space) gets a new box.
			if old := texts[key] {
				if !child.needs_layout_tree_update_() {
					children << old
					kept[key] = true
					continue
				}
			}
			data := child.as_character_data() or { continue }
			text := unsafe { &Node(TextNode.new(update.document, child, data.data())) }
			children << text
			added << text
			continue
		}
		child_element := child.as_element() or { continue }
		if child_element.rendered_in_top_layer() { return update.decline('top-layer-child') }
		child_style := css.computed_properties_for_element(child_element) or {
			return update.decline('unstyled-child')
		}
		if child_style.display().is_contents() { return update.decline('contents-child') }
		if child_style.display().is_none() {
			if key in existing { unrendered << child_element }
			continue
		}
		if old := existing[key] {
			// A kept table keeps its wrapper; its own box carries its style.
			built := if old.is_table_wrapper() { in_place_wrapped_table(old) or { old } } else { old }
			if !child.needs_layout_tree_update_() && !update.forced[key]
				&& built.display() == child_style.display()
				&& retained_flow_style_matches(built, child_style)
				&& !retained_flow_element_has_generated_pseudo_style(child_element) {
				mut keep := true
				if child.child_needs_layout_tree_update_() {
					mark := update.lists.len
					match update.plan_branch(child) {
						.planned {}
						.declined { return false }
						.escalate {
							// A flagged descendant needs this child rebuilt.
							update.lists.trim(mark)
							keep = false
						}
					}
					update.planning = element
				}
				if keep {
					children << old
					kept[key] = true
					continue
				}
			}
		}
		if child_element.shadow_root() != none { return update.decline('shadow-child') }
		rebuild_reason := if in_place_tree_update_diagnostics {
			in_place_rebuild_reason(child, child_style, existing[key] or { unsafe { nil } },
				update.forced[key])
		} else { '' }
		built := build_layout_box_for_element(update.document, child_element, update.style_computer,
			mut update.builder) or { continue }
		if in_place_tree_update_diagnostics {
			count := in_place_subtree_box_count(built)
			// The map outlives the update's workspace.
			persistent := platform.enter_persistent()
			in_place_built_box_counts[rebuild_reason] += count
			platform.leave_persistent(persistent)
		}
		if update.builder.hoisted_pseudo_element_boxes.len != 0 { return update.decline('hoisted') }
		if built.display().is_contents() { return update.decline('contents-child') }
		if built.is_inline() && !built.is_atomic_inline() && in_place_inline_contains_blocks(built) {
			return update.decline('block-in-inline')
		}
		// Table parts outside a table join their siblings in one anonymous
		// table.
		if in_place_display_is_table_part(built.display()) { return update.decline('table-part') }
		new_box := update.fix_new_tables(built)
		if !update.subtree_is_self_contained(new_box) { return false }
		children << new_box
		added << new_box
	}
	children << after
	mut removed := []&Node{}
	for key, old in existing {
		if !kept[key] {
			if !old.is_table_wrapper() && in_place_display_is_table_part(old.display()) {
				return update.decline('table-part')
			}
			if !update.subtree_is_self_contained(old) { return false }
			removed << old
		}
	}
	for key, old in texts {
		if !kept[key] { removed << old }
	}
	update.lists << InPlaceChildList{
		parent:     parent
		computed:   computed
		children:   children
		removed:    removed
		wrappers:   wrappers
		added:      added
		unrendered: unrendered
	}
	return true
}

// Record one current child box: a text box or the box of an element child,
// not split into continuations.
fn (mut update InPlaceTreeUpdate) note_existing_child(child &Node, mut existing map[u64]&Node,
	mut texts map[u64]&Node) bool {
	if child.is_table_wrapper() {
		table := in_place_wrapped_table(child) or {
			if in_place_tree_update_diagnostics {
				mut kinds := []string{}
				for inner in child.children() {
					kinds << '${inner.display()}/anon=${inner.is_anonymous()}/dom=${inner.dom_node() != none}'
				}
				eprintln('VOX_IN_PLACE_TABLE_WRAPPER children=${kinds}')
			}
			return update.decline('table-wrapper-box')
		}
		table_dom := table.dom_node() or { return update.decline('table-wrapper-dom') }
		if table_dom.as_element() == none { return update.decline('table-wrapper-dom') }
		if in_place_box_is_split(table) { return update.decline('table-wrapper-split') }
		existing[u64(voidptr(table_dom))] = child
		return true
	}
	if child.is_anonymous() || child.is_generated_for_pseudo_element() {
		return update.decline('nested-anonymous-child')
	}
	child_dom := child.dom_node() or { return update.decline('unowned-child') }
	// A box whose node was removed or moved elsewhere is dropped: it matches
	// no child below.
	if child.is_text_node() {
		texts[u64(voidptr(child_dom))] = child
		return true
	}
	if child_dom.as_element() == none { return update.decline('unowned-child') }
	if in_place_box_is_split(child) { return update.decline('continuation-child') }
	existing[u64(voidptr(child_dom))] = child
	return true
}

// Why a child's previous box (nil for a child without one) is built again.
fn in_place_rebuild_reason(child &dom.Node, style &css.ComputedProperties, old &Node, forced bool) string {
	if old == unsafe { nil } { return 'new' }
	built := if old.is_table_wrapper() { in_place_wrapped_table(old) or { old } } else { old }
	return if child.needs_layout_tree_update_() {
		'flagged'
	} else if forced {
		'forced'
	} else if built.display() != style.display() {
		'display'
	} else if !retained_flow_style_matches(built, style) {
		'style'
	} else if child.as_element() != none
		&& retained_flow_element_has_generated_pseudo_style(child.as_element() or { panic('element') }) {
		'pseudo'
	} else {
		'escalated'
	}
}

fn in_place_subtree_box_count(node &Node) u64 {
	mut count := u64(1)
	for child in node.children() { count += in_place_subtree_box_count(child) }
	return count
}

fn in_place_display_is_table_part(display css.Display) bool {
	return display.is_internal_table() || display.is_table_caption()
}

fn in_place_has_table_boxes(node &Node) bool {
	display := node.display()
	if node.is_table_wrapper() || display.is_table_inside() || in_place_display_is_table_part(display) {
		return true
	}
	for child in node.children() {
		if in_place_has_table_boxes(child) { return true }
	}
	return false
}

// The table fixups the complete builder runs over the whole tree, for a new
// subtree: anonymous boxes for misparented table parts, whitespace between
// table parts dropped, and wrappers for tables, the subtree's root included.
fn (update &InPlaceTreeUpdate) fix_new_tables(built &Node) &Node {
	if disable_in_place_tables || !in_place_has_table_boxes(built) { return built }
	mut root := unsafe { &Node(built) }
	fixup_table_tree(mut root, update.document)
	if built.display().is_table_inside() { return wrap_table_root(built, update.document) }
	return built
}

// The box itself, or for an anonymous table wrapper the table it holds.
fn in_place_generated_box(box &Node) &Node {
	if box.is_table_wrapper() {
		for child in box.children() {
			if child.display().is_table_inside() { return child }
		}
	}
	return box
}

// The box of the table element an anonymous table wrapper holds.
fn in_place_wrapped_table(wrapper &Node) ?&Node {
	for child in wrapper.children() {
		if !child.is_anonymous() && child.display().is_table_inside() && child.dom_node() != none {
			return child
		}
	}
	return none
}

// Install the planned child lists into the committed tree.
fn (mut update InPlaceTreeUpdate) apply(previous &DocumentLayoutResult) {
	// Past every index of the live tree (boxes never laid out have no
	// committed values) and of the committed values.
	mut next_index := u32(previous.state.used_values_store.pages.len) * layout_state_page_size
	live := highest_layout_index(update.root) + 1
	if live > next_index { next_index = live }
	for list in update.lists {
		mut parent := unsafe { &Node(list.parent) }
		for old in list.removed {
			mut detached := unsafe { &Node(old) }
			detached.parent_ = none
			detached.index_in_parent_ = -1
		}
		for wrapper in list.wrappers {
			mut detached := unsafe { &Node(wrapper) }
			detached.parent_ = none
			detached.index_in_parent_ = -1
			detached.children_.clear()
		}
		parent.invalidate_tree_order()
		parent.children_.clear()
		parent.set_children_are_inline(false)
		attach_children_maintaining_inline_invariant(mut parent, list.children, update.document,
			list.computed)
		for added in list.added {
			next_index = assign_fresh_layout_indexes(added, next_index)
		}
		// The anonymous blocks the attachment made around inline runs.
		for child in parent.children() {
			if child.is_anonymous() && !child.is_generated_for_pseudo_element()
				&& child.tree_order_ == unsafe { nil } {
				if styled := child.as_node_with_style() {
					mut wrapper := unsafe { &NodeWithStyle(styled) }
					wrapper.previous_layout_index_ = next_index
					wrapper.set_layout_index(next_index)
					next_index++
				}
			}
		}
		for element in list.unrendered {
			element.as_node().for_each_shadow_including_inclusive_descendant(fn (node &dom.Node) dom.TraversalDecision {
				return clear_stale_layout_and_paint_node(node, none)
			})
		}
		// Records the parent as an origin of the incremental relayout. New
		// boxes have no committed values and are laid out afresh.
		parent.set_needs_layout_update(true)
	}
	// As the complete builder does: list ordinals derive from the boxes.
	document_node := update.document.as_node()
	document_node.for_each_in_inclusive_subtree(fn (node &dom.Node) dom.TraversalDecision {
		if element := node.as_element() {
			mut mutable_element := unsafe { &dom.Element(element) }
			mutable_element.ordinal_value_ = none
		}
		return .@continue
	})
	recompute_containing_blocks(update.root)
	refresh_layout_tree_order(update.root)
}

// Attaching children invalidates the tree order, which the attachment index,
// ancestor tests and intrinsic seed visits need valid. Renumber the kept
// tree's order in place: the committed pass keyed by the same order object
// still finds unchanged layout indexes, and every node, new ones included,
// gets a valid range.
fn refresh_layout_tree_order(root &Node) {
	if root.tree_order_ == unsafe { nil } || root.tree_order_owner_ != voidptr(root) { return }
	mut order := unsafe { &LayoutTreeOrder(root.tree_order_) }
	order.next_index = 0
	refresh_layout_tree_order_in_subtree(root, mut order)
	order.valid = true
}

fn refresh_layout_tree_order_in_subtree(node &Node, mut order LayoutTreeOrder) {
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.tree_order_ = &order
	mutable_node.tree_order_owner_ = voidptr(node)
	mutable_node.tree_order_start_ = order.next_index
	order.next_index++
	for child in node.children() {
		refresh_layout_tree_order_in_subtree(child, mut order)
	}
	mutable_node.tree_order_end_ = order.next_index
}

// Give every styled node of a new subtree an index no committed box holds.
fn assign_fresh_layout_indexes(node &Node, next u32) u32 {
	mut next_index := next
	if styled := node.as_node_with_style() {
		mut mutable_styled := unsafe { &NodeWithStyle(styled) }
		mutable_styled.previous_layout_index_ = next_index
		mutable_styled.set_layout_index(next_index)
		next_index++
	}
	for child in node.children() {
		next_index = assign_fresh_layout_indexes(child, next_index)
	}
	return next_index
}

fn highest_layout_index(node &Node) u32 {
	mut highest := u32(0)
	if styled := node.as_node_with_style() { highest = styled.layout_index() }
	for child in node.children() {
		value := highest_layout_index(child)
		if value > highest { highest = value }
	}
	return highest
}

// The complete builder constructs some boxes from state that no invalidation
// flag covers, and rebuilt them whenever that state changed, whichever part
// of the tree an update flagged: image kind and availability, form control
// internals and SVG viewport metrics. A kept tree must still be what it
// would build, so any such box built from other state than the current one
// keeps the complete builder.
const in_place_control_names = ['input', 'textarea', 'select', 'progress', 'meter', 'fieldset',
	'legend', 'iframe', 'object', 'embed', 'canvas', 'video', 'audio', 'marquee']

fn (mut update InPlaceTreeUpdate) tree_state_is_current(node &Node) bool {
	if node.is_generated_for_pseudo_element() && generated_content_uses_document_state(node) {
		update.counter_content = true
	}
	if node.is_image_box() {
		if !retained_flow_raster_image_is_ordinary(node) && !retained_svg_image_box_is_current(node) {
			return update.rebuild_stale(node, 'image-state')
		}
	} else if node.is_svg_svg_box() {
		box := node.as_box() or { return update.decline('svg-state') }
		owner := node.dom_node() or { return update.decline('svg-state') }
		element := owner.as_element() or { return update.decline('svg-state') }
		natural := negotiate_svg_natural_metrics(element)
		if box.natural_size_ != natural || box.auto_content_box_size_ != natural {
			return update.rebuild_stale(node, 'svg-metrics')
		}
	} else if node.is_replaced_box() {
		return update.rebuild_stale(node, 'replaced-state')
	} else if is_svg_resource_box(node) {
		return update.decline('svg-resource')
	}
	if !node.is_anonymous() && !node.is_generated_for_pseudo_element() {
		if owner := node.dom_node() {
			if element := owner.as_element() {
				if element.is_html_element() && element.local_name() in in_place_control_names {
					if element.local_name() != 'input' {
						return update.rebuild_stale(node, 'control-state')
					}
					// A materialized model renders through its shadow tree, whose
					// changes carry flags; otherwise the recorded build inputs.
					if element.shadow_root() == none && !input_tree_is_current(element) {
						return update.rebuild_stale(node, 'input-state')
					}
					return true
				}
			}
		}
	}
	for child in node.children() {
		if !update.tree_state_is_current(child) { return false }
	}
	return true
}

// A kept box built from state its element no longer has: its element is
// flagged so that its parent's list rebuilds it, as the complete builder
// would. Its subtree is not scanned further: it is rebuilt with it.
fn (mut update InPlaceTreeUpdate) rebuild_stale(node &Node, reason string) bool {
	if disable_in_place_stale_rebuilds || disable_in_place_escalation || node.is_anonymous()
		|| node.is_generated_for_pseudo_element() {
		return update.decline(reason)
	}
	owner := node.dom_node() or { return update.decline(reason) }
	if owner.as_element() == none { return update.decline(reason) }
	update.stale << owner
	update.note_counter_content_in(node)
	return true
}

fn (mut update InPlaceTreeUpdate) note_counter_content_in(node &Node) {
	if update.counter_content { return }
	if node.is_generated_for_pseudo_element() && generated_content_uses_document_state(node) {
		update.counter_content = true
		return
	}
	for child in node.children() {
		update.note_counter_content_in(child)
	}
}

// An SVG viewport whose subtree is made of plain shapes with no references
// (no href, no url() attribute or paint, clip or mask), so nothing outside it
// instantiates or depends on its content.
fn in_place_svg_is_closed(node &Node) bool {
	if is_svg_resource_box(node) { return false }
	if node.is_text_node() {
		text := node.as_text_node() or { return false }
		return text.text_for_rendering().trim_space() == ''
	}
	owner := node.dom_node() or { return false }
	element := owner.as_element() or { return false }
	if !element.is_svg_element() || element.local_name() !in ['svg', 'g', 'path', 'rect', 'circle',
		'ellipse', 'line', 'polyline', 'polygon'] {
		return false
	}
	if list := element.attribute_list() {
		for index in 0 .. list.length() {
			attribute := list.item(index) or { return false }
			if attribute.local_name() == 'href' || attribute.value().contains('url(') { return false }
		}
	}
	if !retained_simple_svg_style_is_closed(node) { return false }
	for child in node.children() {
		if !in_place_svg_is_closed(child) { return false }
	}
	return true
}
