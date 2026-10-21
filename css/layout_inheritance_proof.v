module css

import dom
import platform

// An anonymous layout wrapper can receive the same inherited values repeatedly
// during tree/style refresh. Keep a proof over both immutable resolved snapshots
// and mutable raw graphs, rather than minting another wide snapshot each time.
@[heap]
pub struct LayoutInheritanceProof {
mut:
	valid bool
	target LayoutInheritanceSnapshot
	source LayoutInheritanceSnapshot
}

struct LayoutInheritanceSnapshot {
mut:
	style &ComputedProperties = unsafe { nil }
	cache &ComputedLayoutCache = unsafe { nil }
	token &ComputedPropertyGraphMutationToken = unsafe { nil }
	generation u64
	important [computed_property_flag_byte_count]u8
	inherited [computed_property_flag_byte_count]u8
	viewport CSSPixelRect
	root_font_size f64
	root_line_height f64
	root_font_depends_on_viewport bool
	line_height CSSPixels
	font_list voidptr
	font_owner voidptr
	font_generation u64
	first_font voidptr
	list_style ListStyleType
}

fn layout_inheritance_can_capture(style &ComputedProperties, document &dom.Document) bool {
	if document == unsafe { nil } { return false }
	cache := style.computed_layout_cache_
	return style.computed_values_resolved_ && cache != unsafe { nil }
		&& cache.writable_owner_identity == 0
		&& voidptr(cache.document_resolution_owner) == voidptr(document)
		&& style.computed_property_graph_token_ != unsafe { nil }
		&& style.computed_property_graph_token_.generation != 0
		&& style.font_variation_storage_ == unsafe { nil }
		&& !style.has_animated_properties() && !style.has_animated_custom_properties()
}

fn inheritance_font_list_identity(style &ComputedProperties) voidptr {
	if fonts := style.cached_computed_font_list_ { return voidptr(fonts) }
	return unsafe { nil }
}

fn (mut snapshot LayoutInheritanceSnapshot) capture(style &ComputedProperties) {
	// Future animation sampling must detach before changing a snapshot observed
	// by this proof, including an animation which starts and finishes between
	// two inherited-style propagations.
	style.share_computed_layout_cache()
	snapshot.style = unsafe { style }
	snapshot.cache = style.computed_layout_cache_
	snapshot.token = style.computed_property_graph_token_
	snapshot.generation = style.mutation_revision()
	snapshot.important = style.property_important_
	snapshot.inherited = style.property_inherited_
	snapshot.viewport = style.viewport_rect_
	snapshot.root_font_size = style.root_font_size_px_
	snapshot.root_line_height = style.root_line_height_px_
	snapshot.root_font_depends_on_viewport = style.root_font_metrics_depend_on_viewport_metrics_
	snapshot.line_height = style.computed_values_line_height_
	snapshot.font_list = inheritance_font_list_identity(style)
	snapshot.font_owner = voidptr(style.cached_computed_font_list_owner_)
	snapshot.font_generation = style.cached_computed_font_list_generation_
	snapshot.first_font = voidptr(style.cached_first_available_computed_font_)
	snapshot.list_style = style.computed_values_list_style_type_
}

fn (snapshot &LayoutInheritanceSnapshot) matches(style &ComputedProperties) bool {
	return voidptr(snapshot.style) == voidptr(style)
		&& voidptr(snapshot.cache) == voidptr(style.computed_layout_cache_)
		&& voidptr(snapshot.token) == voidptr(style.computed_property_graph_token_)
		&& snapshot.generation == style.computed_property_graph_token_.generation
		&& snapshot.important == style.property_important_
		&& snapshot.inherited == style.property_inherited_
		&& snapshot.viewport == style.viewport_rect_
		&& snapshot.root_font_size == style.root_font_size_px_
		&& snapshot.root_line_height == style.root_line_height_px_
		&& snapshot.root_font_depends_on_viewport == style.root_font_metrics_depend_on_viewport_metrics_
		&& snapshot.line_height == style.computed_values_line_height_
		&& snapshot.font_list == inheritance_font_list_identity(style)
		&& snapshot.font_owner == voidptr(style.cached_computed_font_list_owner_)
		&& snapshot.font_generation == style.cached_computed_font_list_generation_
		&& snapshot.first_font == voidptr(style.cached_first_available_computed_font_)
		&& snapshot.list_style == style.computed_values_list_style_type_
}

pub fn layout_inheritance_is_current(proof &LayoutInheritanceProof, target &ComputedProperties,
	source &ComputedProperties, document &dom.Document) bool {
	if proof == unsafe { nil } || !proof.valid { return false }
	target_snapshot := unsafe { &proof.target }
	source_snapshot := unsafe { &proof.source }
	return layout_inheritance_can_capture(target, document)
		&& layout_inheritance_can_capture(source, document)
		&& target_snapshot.matches(target) && source_snapshot.matches(source)
}

pub fn refresh_layout_inheritance_proof(previous &LayoutInheritanceProof,
	target &ComputedProperties, source &ComputedProperties, document &dom.Document) &LayoutInheritanceProof {
	eligible := layout_inheritance_can_capture(target, document)
		&& layout_inheritance_can_capture(source, document)
	if previous == unsafe { nil } && !eligible { return unsafe { nil } }
	mut proof := unsafe { &LayoutInheritanceProof(previous) }
	if proof == unsafe { nil } {
		owner := document.native_storage()
		use_document := owner != unsafe { nil }
			&& voidptr(owner) == voidptr(platform.current_retained_arena())
		mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
		persistent := platform.enter_persistent_if(!use_document)
		proof = &LayoutInheritanceProof{}
		platform.leave_persistent(persistent)
		retained.finish()
	}
	if !eligible && proof.valid {
		proof.target = LayoutInheritanceSnapshot{}
		proof.source = LayoutInheritanceSnapshot{}
	}
	proof.valid = eligible
	if eligible {
		mut target_snapshot := unsafe { &proof.target }
		mut source_snapshot := unsafe { &proof.source }
		target_snapshot.capture(target)
		source_snapshot.capture(source)
	}
	return proof
}
