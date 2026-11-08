module layout

import css
import dom
import os
import platform

fn reject_native_equal_text(reason string) bool {
	if os.getenv('VOX_NATIVE_EQUAL_TEXT_DIAGNOSTICS') != '' {
		eprintln('Vox native equal text declined: ${reason}')
	}
	return false
}

struct NativeEqualTextInput {
	node          &Node
	style         &css.ComputedValues
	revision      u64
	text          string
	dom_text      string
	dom_connected bool
	dom_style     &css.ComputedProperties = unsafe { nil }
	dom_revision  u64
}

@[heap]
struct NativeEqualTextCache {
	width       f64
	height      f64
	scale       f64
	fonts       u64
	environment u64
	inputs      []NativeEqualTextInput
}

struct NativeEqualTextReplacement {
	text  &TextNode
	fresh &dom.Node
}

// This validation index belongs only to the current native layout result.
// Move its reusable vector after replacement geometry has finished consuming
// the old result; published paint/geometry snapshots never read this cache.
fn take_document_equal_text_cache(document &dom.Document) &NativeEqualTextCache {
	mut previous := document_layout_result(document) or { return unsafe { nil } }
	cache := previous.equal_text_cache
	previous.equal_text_cache = unsafe { nil }
	return cache
}

fn collect_native_equal_text_inputs(node &Node, mut inputs []NativeEqualTextInput) {
	// Viewport propagation can replace its synthetic style during an otherwise
	// unchanged update. Its real root/body styles are checked independently.
	if !node.is_viewport() {
		style := node.computed_values()
		mut dom_style := unsafe { &css.ComputedProperties(nil) }
		if !node.is_generated_for_pseudo_element() && !node.is_anonymous() {
			if owner := node.dom_node() {
				if element := owner.as_element() {
					dom_style = css.computed_properties_for_element(element) or { unsafe { nil } }
				}
			}
		}
		inputs << NativeEqualTextInput{
			node:          node
			style:         style
			revision:      style.mutation_revision()
			text:          if text := node.as_text_node() { text.source_text_ } else { '' }
			dom_text:      if owner := node.dom_node() {
				if data := owner.as_character_data() { data.data() } else { '' }
			} else {
				''
			}
			dom_connected: if owner := node.dom_node() { owner.is_connected() } else { false }
			dom_style:     dom_style
			dom_revision:  if dom_style != unsafe { nil } {
				dom_style.mutation_revision()
			} else {
				0
			}
		}
	}
	for child in node.children() { collect_native_equal_text_inputs(child, mut inputs) }
}

fn (mut result DocumentLayoutResult) remember_native_equal_text_inputs(width f64, height f64) {
	document := result.document
	if document.native_storage() == unsafe { nil } || !document.recycle_native_paint_trees {
		return
	}
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut cache := result.equal_text_cache
	if cache == unsafe { nil } { cache = &NativeEqualTextCache{} }
	mut inputs := unsafe { cache.inputs }
	inputs.clear()
	collect_native_equal_text_inputs(result.root, mut inputs)
	unsafe { *cache = NativeEqualTextCache{
		width:       width
		height:      height
		scale:       document.layout_coordinate_scale()
		fonts:       css.css_style_computer_for(document).font_computer().environment_generation()
		environment: document.style_environment_version()
		inputs:      inputs
	} }
	result.equal_text_cache = cache
}

fn collect_native_equal_text_replacements(node &dom.Node,
	mut replacements []NativeEqualTextReplacement) bool {
	if node.needs_layout_tree_update_() {
		element := node.as_element() or { return reject_native_equal_text('dirty non-element') }
		if !element.is_html_element() || element.local_name() !in ['span', 'time']
			|| element.shadow_root() != none || node.is_editable_or_editing_host()
			|| node.children.len != 1 || !node.children[0].is_text() {
			return reject_native_equal_text('dirty subtree ${element.local_name()} children=${node.children.len} editable=${node.is_editable_or_editing_host()}')
		}
		for ancestor := node.parent_or_shadow_host(); ancestor != none; {
			current := ancestor or { break }
			if parent := current.as_element() {
				if !parent.is_html_element() || parent.shadow_root() != none { return false }
			}
			ancestor = current.parent_or_shadow_host()
		}
		mirror := node.unsafe_layout_node() or { return reject_native_equal_text('unboxed ${element.local_name()}') }
		if mirror.real_layout_handle() == unsafe { nil } { return false }
		box := unsafe { &Node(mirror.real_layout_handle()) }
		if !box.is_inline_node() || box.children().len != 1 {
			return reject_native_equal_text('layout ${element.local_name()} inline=${box.is_inline_node()} children=${box.children().len}')
		}
		text := box.children()[0].as_text_node() or { return reject_native_equal_text('non-text layout child') }
		if text.first_letter_ != none || text.source_range_length_ != none
			|| !text.attach_to_dom_node_ || text.is_empty_editable_
			|| text.produces_line_box_fragment_when_empty_ {
			return false
		}
		fresh := node.children[0]
		data := fresh.as_character_data() or { return false }
		old := text.dom_node() or { return false }
		if data.data() == '' || data.data() != text.source_text_ || old.is_connected()
			|| fresh.unsafe_layout_node() != none || text.dom_layout_node_ == unsafe { nil } {
			return reject_native_equal_text('text mismatch=${data.data() != text.source_text_} old_connected=${old.is_connected()} fresh_mirror=${fresh.unsafe_layout_node() != none} old_mirror=${text.dom_layout_node_ != unsafe { nil }}')
		}
		replacements << NativeEqualTextReplacement{ text: text, fresh: fresh }
		return true
	}
	if node.child_needs_layout_tree_update_() {
		for child in node.children {
			if !collect_native_equal_text_replacements(child, mut replacements) { return false }
		}
	}
	return true
}

// DOM replacement still creates fresh Text identities, adjusts ranges and
// queues its mutation records. Only the native renderer's unchanged geometry
// is reused. Validate every input before rebinding any layout/paint boundary.
fn (mut result DocumentLayoutResult) reuse_native_equal_text(width f64, height f64) bool {
	cache := result.equal_text_cache
	document := result.document
	if cache == unsafe { nil } || document.needs_full_layout_tree_update()
		|| cache.width != width || cache.height != height
		|| cache.scale != document.layout_coordinate_scale()
		|| cache.environment != document.style_environment_version()
		|| cache.fonts != css.css_style_computer_for(document).font_computer().environment_generation() {
		if cache != unsafe { nil } && os.getenv('VOX_NATIVE_EQUAL_TEXT_DIAGNOSTICS') != '' {
			eprintln('Vox native equal text inputs: full=${document.needs_full_layout_tree_update()} viewport=${cache.width},${cache.height}/${width},${height} scale=${cache.scale}/${document.layout_coordinate_scale()} environment=${cache.environment}/${document.style_environment_version()} fonts=${cache.fonts}/${css.css_style_computer_for(document).font_computer().environment_generation()}')
		}
		return reject_native_equal_text('document inputs')
	}
	mut work := platform.begin_thread_scratch('native equal text validation')
	defer { work.finish() }
	mut replacements := []NativeEqualTextReplacement{}
	if !collect_native_equal_text_replacements(document.as_node(), mut replacements)
		|| replacements.len == 0 {
		return reject_native_equal_text('DOM invalidations')
	}
	mut replaced := map[u64]bool{}
	mut ancestors := map[u64]bool{}
	for replacement in replacements {
		replaced[u64(voidptr(replacement.text))] = true
		for parent := replacement.text.parent(); parent != none; {
			current := parent or { break }
			ancestors[u64(voidptr(current))] = true
			parent = current.parent()
		}
	}
	// Style comparison may initialize retained font/content caches. The maps
	// remain readable until finish(), while those writes use document storage.
	work.leave()
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	for input in cache.inputs {
		node := input.node
		if voidptr(node.computed_values()) != voidptr(input.style)
			|| input.style.mutation_revision() != input.revision || input.revision == 0
			|| (node.needs_layout_update() && (!ancestors[u64(voidptr(node))]
				|| node.is_replaced_box())) {
			return reject_native_equal_text('style/dirty input same_style=${voidptr(node.computed_values()) == voidptr(input.style)} revision=${input.revision}/${input.style.mutation_revision()} dirty=${node.needs_layout_update()} allowed=${ancestors[u64(voidptr(node))]}')
		}
		if element := node.dom_node() {
			if owner := element.as_element() {
				// Generated control wrappers can have synthetic, disconnected
				// DOM owners. Their original connection state must remain stable;
				// removing a previously connected owner still rejects reuse.
				if element.is_connected() != input.dom_connected {
					return reject_native_equal_text('connection changed for ${owner.local_name()}')
				}
				if input.dom_style != unsafe { nil } {
					if input.dom_revision == 0 || input.dom_style.mutation_revision() != input.dom_revision {
						return reject_native_equal_text('DOM revision ${owner.local_name()} ${input.dom_revision}/${input.dom_style.mutation_revision()}')
					}
					computed := css.computed_properties_for_element(owner) or { return false }
					if voidptr(computed) != voidptr(input.dom_style) {
						// Replacing a child recascades its parent even when every
						// effective property is unchanged. Use the same complete
						// property/font invalidation check as ordinary restyling.
						abstract := dom.AbstractElement.new(owner, none)
						invalidation := css.compute_required_invalidation(input.dom_style, computed,
							css.css_style_computer_for(document).font_computer(), abstract.unsafe_layout_node(), abstract)
						if !invalidation.is_none() {
							return reject_native_equal_text('DOM style ${owner.local_name()}')
						}
					}
				}
			}
		}
		if node.is_text_node() && !replaced[u64(voidptr(node))] {
			text := node.as_text_node() or { return false }
			if text.source_text_ != input.text {
				return reject_native_equal_text('layout text changed')
			}
			if node.is_generated_text_node() {
				continue
			}
			owner := node.dom_node() or { return reject_native_equal_text('text has no DOM owner') }
			data := owner.as_character_data() or { return reject_native_equal_text('text owner is not character data') }
			if owner.is_connected() != input.dom_connected || data.data() != input.dom_text {
				return reject_native_equal_text('text owner connection_same=${owner.is_connected() == input.dom_connected} same_data=${data.data() == input.dom_text}')
			}
		}
	}
	if cache.fonts != css.css_style_computer_for(document).font_computer().environment_generation() {
		return false
	}
	for replacement in replacements {
		mut text := unsafe { &TextNode(replacement.text) }
		mut mirror := text.dom_layout_node_
		text.dom_node_ = replacement.fresh
		mirror.dom_node_ = replacement.fresh
		mut fresh := unsafe { &dom.Node(replacement.fresh) }
		fresh.set_layout_node(mirror)
		if mirror.paintables_.len > 0 { fresh.set_paintable(mirror.paintables_[0]) }
	}
	// Paint-run keys follow the retained layout node; hit testing and selection
	// read its new DOM owner. Rebinding needs no new projection or phase payloads.
	// Preserve any independently pending paint update (for example an image load).
	result.root.for_each_in_inclusive_subtree(fn (node &Node) dom.TraversalDecision {
		mut current := unsafe { &Node(node) }
		current.reset_needs_layout_update()
		if current.dom_layout_node_ != unsafe { nil } {
			current.dom_layout_node_.needs_layout_update_ = false
		}
		return .@continue
	})
	if os.getenv('VOX_NATIVE_EQUAL_TEXT_DIAGNOSTICS') != '' {
		eprintln('Vox native equal text: reused ${replacements.len} text replacements')
	}
	return true
}
