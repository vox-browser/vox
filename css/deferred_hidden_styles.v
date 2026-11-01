module css

import dom
import os
import platform

const disable_deferred_hidden_styles = os.getenv('VOX_DISABLE_DEFERRED_HIDDEN_STYLES') != ''
const deferred_hidden_style_diagnostics = os.getenv('VOX_DEFERRED_HIDDEN_STYLE_DIAGNOSTICS') != ''

__global (
	deferred_hidden_style_reported bool
	materialized_hidden_style_reported bool
)

// Limit the initial optimization to ordinary HTML content. Resource trees,
// controls, shadow inheritance and top-layer content keep eager computation.
fn plain_hidden_style_subtree(node &dom.Node) bool {
	if element := node.as_element() {
		if !element.is_html_element() || element.shadow_root() != none
			|| element.rendered_in_top_layer() || element.has_attribute('popover')
			|| node.assigned_slot_internal() != none
			|| element.local_name() !in ['div','section','article','aside','header','footer',
				'main','nav','p','span','a','strong','b','em','i','s','del','small','code','pre',
				'blockquote','h1','h2','h3','h4','h5','h6','ul','ol','li','time','br'] {
			return false
		}
	}
	for child in node.children {
		if !plain_hidden_style_subtree(child) { return false }
	}
	return true
}

fn can_defer_hidden_child_styles(node &dom.Node) bool {
	if node.root().as_shadow_root() != none { return false }
	mut has_element_child := false
	for child in node.children { if child.is_element() { has_element_child = true; break } }
	if !has_element_child { return false }
	mut ancestor := node.parent_or_shadow_host()
	for ancestor != none {
		current := ancestor or { break }
		if element := current.as_element() {
			if !element.is_html_element() || element.shadow_root() != none
				|| element.rendered_in_top_layer() || element.has_attribute('popover') {
				return false
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return plain_hidden_style_subtree(node)
}

fn clear_deferred_descendant_style_flags(node &dom.Node) {
	for child in node.children {
		clear_deferred_descendant_style_flags(child)
		mut mutable_child := unsafe { &dom.Node(child) }
		mutable_child.set_needs_style_update(false)
		mutable_child.set_child_needs_style_update(false)
		mutable_child.set_entire_subtree_needs_style_update(false)
	}
	mut mutable_node := unsafe { &dom.Node(node) }
	mutable_node.set_child_needs_style_update(false)
}

// Deferred keys describe children, never the root's own completed style. Only
// primitive node identities are retained; adoption/removal cannot leave an
// owning pointer in another document. Saturation falls back to eager styling.
fn (mut computer StyleComputer) prepare_hidden_child_style_update(node &dom.Node,
	hidden bool, needs_update bool) (bool, bool) {
	key := u64(node.unique_id().value())
	was_deferred := computer.deferred_hidden_styles_[key]
	if !disable_deferred_hidden_styles && hidden && needs_update
		&& (was_deferred || computer.deferred_hidden_styles_.len < 4096)
		&& can_defer_hidden_child_styles(node) {
		computer.deferred_hidden_styles_[key] = true
		clear_deferred_descendant_style_flags(node)
		if deferred_hidden_style_diagnostics && !deferred_hidden_style_reported {
			deferred_hidden_style_reported = true
			eprintln('Vox hidden styles: deferred ordinary unrendered descendants')
		}
		return true, false
	}
	if was_deferred && (!hidden || needs_update) {
		computer.deferred_hidden_styles_.delete(key)
		return false, true
	}
	return false, false
}

// CSSOM queries explicitly refresh the deferred branch before reading it.
// Complete-subtree recomputation preserves inheritance, pseudo styles and
// selector dependency metadata, including mutations made while it was hidden.
fn (mut computer StyleComputer) materialize_hidden_styles_for_query(element &dom.Element) {
	if computer.deferred_hidden_styles_.len == 0 || computer.materializing_hidden_styles_ { return }
	mut root := ?&dom.Element(none)
	mut ancestor := element.element_to_inherit_style_from(none)
	for ancestor != none {
		current := ancestor or { break }
		if computer.deferred_hidden_styles_[u64(current.as_node().unique_id().value())] { root = current }
		ancestor = current.element_to_inherit_style_from(none)
	}
	owner := root or { return }
	mut storage := element.document().native_storage()
	mut allocations := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocations = storage.enter_nested() }
	defer { allocations.finish() }
	computer.materializing_hidden_styles_ = true
	defer { computer.materializing_hidden_styles_ = false }
	mut ancestors := []&dom.Element{}
	mut parent := owner.as_node().parent_element()
	for parent != none {
		current := parent or { break }
		ancestors << current
		computer.push_ancestor(current)
		parent = current.as_node().parent_element()
	}
	defer { for current in ancestors { computer.pop_ancestor(current) } }
	computer.reset_has_result_cache()
	recompute_style_for_subtree(mut computer, owner.as_node())
	if deferred_hidden_style_diagnostics && !materialized_hidden_style_reported {
		materialized_hidden_style_reported = true
		eprintln('Vox hidden styles: materialized queried branch')
	}
}
