module css

import dom
import os

const retain_font_size_unit_longhands = os.getenv('VOX_RETAIN_FONT_SIZE_UNIT_LONGHANDS') != ''
const font_size_unit_longhand_diagnostics = os.getenv('VOX_FONT_SIZE_UNIT_LONGHAND_DIAGNOSTICS') != ''
__global font_size_unit_longhand_reported bool

// Only direct em/rem longhands: their scalar font-size bases are guarded by
// the inherited/cascaded input snapshots and the root/font-policy key. Glyph
// metrics, line-height units, calculations and composite values stay excluded.
fn font_size_unit_longhand_is_reusable(value &dom.StyleValue) bool {
	if retain_font_size_unit_longhands || value.css_value_handle == unsafe { nil } { return false }
	typed := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	if typed.value is LengthStyleValue { return typed.value.length_.unit_ in [.em, .rem] }
	return false
}

fn (s &StyleComputer) longhand_live_root_font_size() ?f64 {
	root := s.document_.document_element() or { return none }
	bridge := root.el_computed_properties() or { return none }
	computed := computed_properties_from_dom(bridge) or { return none }
	return if s.document_.font_rendering_policy() == .chromium {
		computed.resolved_font_size_px()
	} else { computed.font_size().to_double() }
}

struct FontSizeLonghandEnvironment {
	viewport CSSPixelRect
	root_size f64
	root_unrounded ?f64
	live_root ?f64
	root_viewport bool
	policy dom.FontRenderingPolicy
}

// Before any cached result exists, a single-use relative style need not hash
// its complete inherited environment or retain its output. This is only an
// admission hint: every later hit still builds and validates the complete key.
fn (s &StyleComputer) font_size_longhand_question_is_repeated(parent &ComputedProperties, cascade_hash u64) bool {
	mut arena := s.computed_property_page_index_arena()
	allocation := arena.enter()
	defer { arena.leave(allocation) }
	mut owner := unsafe { &StyleComputer(s) }
	if owner.longhand_reuse_cache_ == unsafe { nil } { owner.longhand_reuse_cache_ = &ComputedLonghandReuseCache{} }
	mut cache := owner.longhand_reuse_cache_
	hint := u64(voidptr(parent)) ^ cascade_hash
	if cache.font_size_unit_seen[hint] { return true }
	if cache.font_size_unit_seen.len < 512 { cache.font_size_unit_seen[hint] = true }
	return false
}

// Root/policy changes inside one synchronous batch are uncommon. Once seen,
// leave relative declarations on the full computation path for this batch;
// absolute-value reuse remains available. The next outer batch starts fresh.
fn (s &StyleComputer) font_size_longhand_environment_is_stable(key &ComputedLonghandReuseKey) bool {
	mut arena := s.computed_property_page_index_arena()
	allocation := arena.enter()
	defer { arena.leave(allocation) }
	mut owner := unsafe { &StyleComputer(s) }
	if owner.longhand_reuse_cache_ == unsafe { nil } { owner.longhand_reuse_cache_ = &ComputedLonghandReuseCache{} }
	mut cache := owner.longhand_reuse_cache_
	if cache.font_size_unit_environment_changed { return false }
	environment := FontSizeLonghandEnvironment{viewport:key.viewport, root_size:key.root_font_size,
		root_unrounded:key.root_font_size_unrounded, live_root:key.live_root_font_size,
		root_viewport:key.root_font_viewport, policy:key.font_policy}
	if previous := cache.font_size_unit_environment {
		if previous != environment { cache.font_size_unit_environment_changed = true; return false }
	} else { cache.font_size_unit_environment = environment }
	return true
}

// Later inheritance refreshes need the original relative declarations. Cache
// their property IDs, then rebuild a caller-owned map from this hit's current
// declaration wrappers. Never share another style's writable map or sources.
fn font_size_unit_specified_ids(computed &ComputedProperties, cascaded &CascadedProperties) ?[]PropertyID {
	mut ids := []PropertyID{}
	if computed.inheritance_specified_storage_ == unsafe { nil } { return ids }
	for id, value in computed.inheritance_specified_storage_.values {
		property := cascaded.style_property(id) or { return none }
		if voidptr(value) != voidptr(property.value)
			|| !font_size_unit_longhand_is_reusable(property.value) { return none }
		ids << id
	}
	return ids
}

fn report_font_size_unit_longhand_reuse(inputs []ComputedLonghandReuseInput) {
	if !font_size_unit_longhand_diagnostics || font_size_unit_longhand_reported { return }
	for input in inputs {
		if input.snapshot.kind == .length && input.snapshot.length_unit in [.em, .rem] {
			font_size_unit_longhand_reported = true
			eprintln('Vox font-size longhands: restored guarded direct em/rem inputs')
			return
		}
	}
}
