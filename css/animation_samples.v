module css

import dom
import os
import platform
import sync.stdatomic

const disable_animation_sample_word_prefilter = os.getenv('VOX_DISABLE_ANIMATION_SAMPLE_WORD_PREFILTER') != ''
const animation_sample_word_diagnostics = os.getenv('VOX_ANIMATION_SAMPLE_WORD_DIAGNOSTICS') != ''

__global animation_sample_word_reported stdatomic.AtomicVal[bool]

// Storage for sampled animation values under -prealloc.
//
// Every rendering update recomputes each animated target's keyframe values
// and interpolates them, and the results replace the previous frame's values.
// Those samples are allocated in an arena instead of ordinary storage, so a
// document that animates indefinitely reuses a bounded amount of memory.
//
// A sample stays reachable after it is replaced: published display lists,
// paint and layout data derived from a style, descendants that inherited it,
// and transitions that captured it can all point at it. So the current arena
// is not reset in place. Once it has filled up, a later update starts a new
// arena and re-installs every target (its style, descendants, layout style and
// paint), and the old arena is reset only after all of these hold:
//   - no style of a target that sampled into it, or of such a target's
//     descendants, still points into it;
//   - every display list recorded while it was current has been released;
//   - no layout pass committed while it was current is still in use.
// Transitions copy any sample they capture (see copy_sampled_style_value).
//
// Hosted recordings participate through their retained child-scene leases.
// Builds without -prealloc keep samples in ordinary storage.

// A sample arena holds at least this many bytes, and at least this many
// updates' worth of samples, before the next update starts a new one. Each
// change of arena re-installs every target.
const animation_sample_arena_bytes = i64(256 * 1024)
const animation_sample_arena_updates = i64(16)

@[heap]
struct AnimationSampleStorage {
mut:
	current &platform.Arena = unsafe { nil }
	// Layout pass and display list generations when `current` started.
	current_layout_generation u64
	current_targets           []AnimationSampleTarget
	// Arena serial in which each target was last recorded, and its index in
	// that arena's target list. Overwriting existing keys allocates nothing.
	current_serial      u64
	target_serials      map[i64]u64
	target_indices      map[i64]int
	retiring            []RetiringAnimationSamples
	spare               []&platform.Arena
	spare_target_lists  []AnimationSampleTargetList
	// Decaying maximum of the sample bytes one update allocates, and the
	// current arena's use when this update began.
	update_bytes      i64
	update_start_used i64
	entry                     platform.ArenaEntry
	// enter/leave pairs nest; only the outermost switches the arena.
	depth int
}

struct AnimationSampleTarget {
mut:
	element dom.AbstractElement
	// The target installed an inherited property: descendants may hold it.
	inherited bool
}

// Appending a nested array makes current V clone its backing store. Transfer
// these already owned vectors in a record so arena rotation reuses them.
struct AnimationSampleTargetList {
	items []AnimationSampleTarget
}

struct RetiringAnimationSamples {
mut:
	arena   &platform.Arena = unsafe { nil }
	targets []AnimationSampleTarget
	// Layout pass generations when the arena started and stopped receiving
	// samples. A pass committed in between may hold samples until replaced.
	created_layout_generation u64
	retired_layout_generation u64
	// Set once no target style points into the arena: display lists recorded
	// up to this generation may still read it.
	holders_cleared        bool
	last_scene_generation u64
	// Updates since the styles were last inspected; a target that keeps an
	// old sample (one skipped while hidden) is not rescanned every frame.
	updates_since_inspection int
}

const animation_sample_inspection_interval = 8

// Component diagnostics compare arena recycling with document-owned sample
// allocations. Select this before the first animation update; it changes no
// document or display-list ownership and does not pin either lifetime.
pub fn (mut s StyleComputer) disable_animation_sample_arenas() {
	assert s.animation_samples_ == unsafe { nil }
	s.animation_sample_arenas_disabled_ = true
}

fn (mut s StyleComputer) animation_sample_storage() &AnimationSampleStorage {
	$if prealloc {
		if s.document_ == unsafe { nil } || s.animation_sample_arenas_disabled_ {
			return unsafe { nil }
		}
		if s.animation_samples_ == unsafe { nil } {
			persistent := platform.enter_persistent()
			s.animation_samples_ = &AnimationSampleStorage{}
			platform.leave_persistent(persistent)
			mut owner := s.document_.native_storage()
			if owner != unsafe { nil } {
				samples := s.animation_samples_
				owner.add_cleanup(fn [samples] () {
					mut retiring := unsafe { &AnimationSampleStorage(samples) }
					retiring.dispose()
				})
			}
		}
		return s.animation_samples_
	}
	return unsafe { nil }
}

fn (mut storage AnimationSampleStorage) dispose() {
	assert storage.depth == 0
	if storage.current != unsafe { nil } { storage.current.release() }
	for mut retiring in storage.retiring { retiring.arena.release() }
	for mut spare in storage.spare { spare.release() }
	storage.current = unsafe { nil }
	storage.current_targets.clear()
	storage.retiring.clear()
	storage.spare.clear()
	storage.spare_target_lists.clear()
	storage.target_serials.clear()
	storage.target_indices.clear()
}

// begin_update retires arenas nothing can reach any longer and, when the
// current arena is full, starts a new one. It returns true when this update
// must re-install every target so the previous arena can be released.
fn (mut storage AnimationSampleStorage) begin_update(document &dom.Document) bool {
	storage.retire_unreachable(document)
	if storage.current == unsafe { nil } {
		storage.start_arena(document)
		storage.update_start_used = 0
		return false
	}
	used := storage.current.usage().used
	previous_update := used - storage.update_start_used
	storage.update_bytes = if previous_update > storage.update_bytes {
		previous_update
	} else {
		storage.update_bytes - storage.update_bytes / 8
	}
	original_limit := if animation_sample_arena_updates * storage.update_bytes > animation_sample_arena_bytes {
		animation_sample_arena_updates * storage.update_bytes
	} else {
		animation_sample_arena_bytes
	}
	limit := if retain_short_animation_sample_batch {
		original_limit
	} else {
		expanded_animation_sample_arena_limit(original_limit, storage.update_bytes)
	}
	if !retain_short_animation_sample_batch && animation_sample_batch_diagnostics {
		report_animation_sample_batch_extension(document, used, original_limit, limit)
	}
	if used < limit {
		storage.update_start_used = used
		return false
	}
	persistent := platform.enter_persistent()
	storage.retiring << RetiringAnimationSamples{
		arena:                     storage.current
		targets:                   storage.current_targets
		created_layout_generation: storage.current_layout_generation
		retired_layout_generation: document.layout_pass_generation
	}
	storage.current_targets = if storage.spare_target_lists.len > 0 {
		storage.spare_target_lists.pop().items
	} else {
		[]AnimationSampleTarget{}
	}
	platform.leave_persistent(persistent)
	storage.start_arena(document)
	storage.update_start_used = 0
	return true
}

fn (mut storage AnimationSampleStorage) start_arena(document &dom.Document) {
	persistent := platform.enter_persistent()
	storage.current = if storage.spare.len > 0 {
		storage.spare.pop()
	} else {
		platform.new_arena('animation samples')
	}
	platform.leave_persistent(persistent)
	storage.current_layout_generation = document.layout_pass_generation
	storage.current_serial++
}

// The sample storage when `style` is the animated target being re-resolved
// for layout in this update, nil otherwise.
fn (s &StyleComputer) animation_layout_samples(style &ComputedProperties) &AnimationSampleStorage {
	if !s.sampling_animation_frame_ || s.animation_layout_style_ == unsafe { nil }
		|| voidptr(s.animation_layout_style_) != voidptr(style) {
		return unsafe { nil }
	}
	return s.animation_samples_
}

// Record that `target` installed samples from the current arena.
fn (mut storage AnimationSampleStorage) note_target(target dom.AbstractElement, inherited bool) {
	key := abstract_element_storage_key(target)
	if storage.target_serials[key] or { 0 } == storage.current_serial {
		if inherited {
			index := storage.target_indices[key] or { return }
			storage.current_targets[index].inherited = true
		}
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	storage.target_serials[key] = storage.current_serial
	storage.target_indices[key] = storage.current_targets.len
	storage.current_targets << AnimationSampleTarget{
		element:   target
		inherited: inherited
	}
}

// Route allocations into the current sample arena until leave().
fn (mut storage AnimationSampleStorage) enter() {
	if storage == unsafe { nil } {
		return
	}
	if storage.depth == 0 {
		storage.entry = storage.current.enter()
	}
	storage.depth++
}

fn (mut storage AnimationSampleStorage) leave() {
	if storage == unsafe { nil } || storage.depth == 0 {
		return
	}
	storage.depth--
	if storage.depth == 0 {
		storage.current.leave(storage.entry)
	}
}

// contains reports whether `pointer` is a sample from any arena, current or
// retiring.
fn (storage &AnimationSampleStorage) contains(pointer voidptr) bool {
	if storage == unsafe { nil } || pointer == unsafe { nil } {
		return false
	}
	if storage.current != unsafe { nil } && storage.current.contains(pointer) {
		return true
	}
	for retiring in storage.retiring {
		if retiring.arena.contains(pointer) {
			return true
		}
	}
	return false
}

fn (storage &AnimationSampleStorage) in_retiring(pointer voidptr) bool {
	if storage == unsafe { nil } || pointer == unsafe { nil } {
		return false
	}
	for retiring in storage.retiring {
		if retiring.arena.contains(pointer) {
			return true
		}
	}
	return false
}

fn (mut storage AnimationSampleStorage) retire_unreachable(document &dom.Document) {
	if storage.retiring.len == 0 {
		return
	}
	mut kept := 0
	for index in 0 .. storage.retiring.len {
		mut retiring := storage.retiring[index]
		if !retiring.holders_cleared {
			if retiring.updates_since_inspection % animation_sample_inspection_interval == 0
				&& !retiring.styles_reference_arena() {
				retiring.holders_cleared = true
				retiring.last_scene_generation = document.paint_scene_generation
			}
			retiring.updates_since_inspection++
		}
		layout_released := retiring.created_layout_generation == retiring.retired_layout_generation
			|| document.layout_pass_generation > retiring.retired_layout_generation
		if retiring.holders_cleared && layout_released
			&& document.oldest_live_paint_scene_generation > retiring.last_scene_generation {
			mut arena := retiring.arena
			arena.reset()
			persistent := platform.enter_persistent()
			if storage.spare.len < 2 {
				storage.spare << arena
			} else {
				arena.release()
			}
			// The target list's storage is reused by a later arena.
			mut targets := unsafe { retiring.targets }
			targets.clear()
			if storage.spare_target_lists.len < 2 {
				storage.spare_target_lists << AnimationSampleTargetList{items:targets}
			}
			platform.leave_persistent(persistent)
			continue
		}
		storage.retiring[kept] = retiring
		kept++
	}
	storage.retiring.trim(kept)
}

fn (retiring &RetiringAnimationSamples) styles_reference_arena() bool {
	scratch := platform.begin_thread_scratch('animation reference inspection')
	defer { scratch.finish() }
	mut scan := AnimationSampleReferenceScan{retiring: retiring}
	return scan.styles_reference_arena()
}

fn (mut scan AnimationSampleReferenceScan) styles_reference_arena() bool {
	retiring := scan.retiring
	for target in retiring.targets {
		if scan.element_style_references_arena(target.element) {
			return true
		}
		if target.inherited
			&& scan.descendant_styles_reference_arena(target.element.element().as_node()) {
			return true
		}
	}
	return false
}

// The element's style, the style its layout node last applied, and its
// animated custom-property overlay.
fn (mut scan AnimationSampleReferenceScan) element_style_references_arena(target dom.AbstractElement) bool {
	retiring := scan.retiring
	if dom_computed := target.computed_properties() {
		if retiring.arena.contains(voidptr(dom_computed)) {
			return true
		}
		if computed := computed_properties_from_dom(dom_computed) {
			if scan.computed_references_arena_at_depth(computed, 0) {
				return true
			}
		}
	}
	if styled := target.unsafe_layout_node() {
		if applied := styled.applied_properties_ {
			if retiring.arena.contains(voidptr(applied)) {
				return true
			}
			if computed := computed_properties_from_dom(applied) {
				if scan.computed_references_arena_at_depth(computed, 0) {
					return true
				}
			}
		}
	}
	// The custom-property chain: an animation overlay, or the data of a
	// descendant whose parent is one.
	mut data := target.custom_property_data()
	for {
		current := data or { break }
		if retiring.arena.contains(voidptr(current)) {
			return true
		}
		for _, property in current.own_values {
			if retiring.arena.contains(voidptr(property.value))
				|| retiring.arena.contains(property.value.css_value_handle)
				|| retiring.arena.contains(voidptr(property.value.css_text.str)) {
				return true
			}
		}
		data = current.parent
	}
	return false
}

fn (mut scan AnimationSampleReferenceScan) descendant_styles_reference_arena(node &dom.Node) bool {
	mut child := node.first_child()
	for {
		current := child or { break }
		if element := current.as_element() {
			if scan.element_style_references_arena(dom.AbstractElement.new(element, none))
				|| scan.element_style_references_arena(dom.AbstractElement.new(element, dom.PseudoElement.before))
				|| scan.element_style_references_arena(dom.AbstractElement.new(element, dom.PseudoElement.after)) {
				return true
			}
		}
		if scan.descendant_styles_reference_arena(current) {
			return true
		}
		child = current.next_sibling()
	}
	return false
}

fn (retiring &RetiringAnimationSamples) value_references_arena(value &dom.StyleValue) bool {
	return value != unsafe { nil } && (retiring.arena.contains(voidptr(value))
		|| retiring.arena.contains(voidptr(value.css_text.str))
		|| retiring.arena.contains(value.css_value_handle)
		// A persistent typed box can still borrow component arrays from a
		// sample. Keep those arrays alive with the installed value, too.
		|| (value.css_value_handle != unsafe { nil }
			&& retiring.struct_references_arena(value.css_value_handle, int(sizeof(TypedStyleValueBox)))))
}

// Whether any value of `computed`, or its materialized layout snapshot, is
// stored in the arena. Values are checked with their text, which other values
// can share as slices. The snapshot is scanned word by word: it holds copies of
// typed values whose own pointers may lead into a sample.
fn (retiring &RetiringAnimationSamples) computed_references_arena(computed &ComputedProperties) bool {
	scratch := platform.begin_thread_scratch('animation reference inspection')
	defer { scratch.finish() }
	mut scan := AnimationSampleReferenceScan{retiring: retiring}
	return scan.computed_references_arena_at_depth(computed, 0)
}

fn (mut scan AnimationSampleReferenceScan) computed_references_arena_at_depth(computed &ComputedProperties, depth int) bool {
	retiring := scan.retiring
	if computed == unsafe { nil } { return false }
	// Density projections normally form a single derived snapshot. Retain an
	// arena conservatively if a malformed or unusually deep chain appears.
	if depth >= 8 { return true }
	// Fields materialized outside the snapshot, such as content and list
	// markers, are rewritten by each resolve like the snapshot itself.
	if retiring.struct_references_arena(voidptr(computed), int(sizeof(ComputedProperties))) {
		return true
	}
	// Copy-on-write can allocate just a property page while the computed
	// style, its store and every value remain in longer-lived storage. The
	// page itself must survive until the installed style stops reading it.
	if computed.property_store_ != unsafe { nil } {
		for index, page in computed.property_store_.pages {
			if retiring.arena.contains(voidptr(page)) {
				if os.getenv('VOX_ANIMATION_SAMPLE_PAGE_DIAGNOSTICS') != '' {
					eprintln('VOX_ANIMATION_SAMPLE_PAGE_HOLD page=${index}')
				}
				return true
			}
		}
	}
	if scan.use_property_pages && computed.property_store_ != unsafe { nil } {
		for index, page in computed.property_store_.pages {
			remaining := number_of_longhand_properties - index * computed_property_page_size
			count := if remaining < computed_property_page_size { remaining } else { computed_property_page_size }
			if scan.property_page_references_arena(page, count) { return true }
		}
	} else {
		for index in 0 .. computed.raw_property_count() {
			if retiring.value_references_arena(computed.raw_property_at_index(index)) {
				return true
			}
		}
	}
	if computed.animated_property_storage_ != unsafe { nil } {
		for _, value in computed.animated_property_storage_.values {
			if retiring.value_references_arena(value) {
				return true
			}
		}
	}
	if computed.animated_custom_storage_ != unsafe { nil } {
		for _, value in computed.animated_custom_storage_.values {
			if retiring.value_references_arena(value) {
				return true
			}
		}
	}
	cache := computed.computed_layout_cache_
	if cache != unsafe { nil } {
		if retiring.struct_references_arena(voidptr(cache), int(sizeof(ComputedLayoutCache))) {
			return true
		}
		// Rare values (transforms, filters, SVG geometry) live in their own
		// record, which a sample may have filled while the record itself was
		// allocated earlier.
		if cache.rare_data_ != unsafe { nil }
			&& retiring.struct_references_arena(voidptr(cache.rare_data_), int(sizeof(ComputedLayoutRareData))) {
			return true
		}
	}
	// Retina layout borrows dimensionless properties and resolves its own
	// snapshot. The CSS source may already have replaced its samples while
	// that projected style is still installed on a layout node.
	projection := computed.device_layout_projection_
	if projection != unsafe { nil } {
		if retiring.struct_references_arena(voidptr(projection), int(sizeof(DeviceLayoutStyleProjection)))
			|| (projection.provenance != unsafe { nil }
				&& retiring.struct_references_arena(voidptr(projection.provenance), int(sizeof(ComputedGeometryProvenance))))
			|| scan.computed_references_arena_at_depth(projection.style, depth + 1) {
			if os.getenv('VOX_ANIMATION_SAMPLE_PAGE_DIAGNOSTICS') != '' {
				eprintln('VOX_ANIMATION_SAMPLE_PROJECTION_HOLD depth=${depth}')
			}
			return true
		}
	}
	return false
}

// Scan a struct's words for pointers into the arena.
fn (retiring &RetiringAnimationSamples) struct_references_arena(start voidptr, size int) bool {
	if !disable_animation_sample_word_prefilter {
		if animation_sample_word_diagnostics && animation_sample_word_reported.compare_and_swap(false, true) {
			eprintln('Vox animation sample word prefilter executed')
		}
		return unsafe { retiring.arena.contains_any_word(start, size) }
	}
	words := unsafe { &voidptr(start) }
	for index in 0 .. size / int(sizeof(voidptr)) {
		if retiring.arena.contains(unsafe { words[index] }) {
			return true
		}
	}
	return false
}

// A sample being installed must come from the current arena: composition can
// hand back the underlying value, which may still be an older frame's sample.
fn (mut storage AnimationSampleStorage) adopt(value &dom.StyleValue) &dom.StyleValue {
	if storage == unsafe { nil } || !storage.in_retiring(voidptr(value)) {
		return unsafe { value }
	}
	storage.enter()
	defer { storage.leave() }
	mut working_copy := &dom.StyleValue{
		css_text: value.css_text.clone()
	}
	if url := value.base_url {
		working_copy.base_url = url.clone()
	}
	return working_copy
}

fn document_animation_samples(document &dom.Document) &AnimationSampleStorage {
	if document == unsafe { nil } || document.style_computer == unsafe { nil }
		|| document.style_computer.css_handle == unsafe { nil } {
		return unsafe { nil }
	}
	computer := unsafe { &StyleComputer(document.style_computer.css_handle) }
	return computer.animation_samples_
}

// Paint boxes keep their style's background layers until the box is next
// rebuilt, which can be after the style's sample arena has been reset. An
// animation frame re-resolves its target's layers into that arena even when
// they do not animate, so copy sampled layers into ordinary storage.
pub fn background_layers_outside_samples(document &dom.Document, layers []BackgroundLayerData) []BackgroundLayerData {
	$if prealloc {
		storage := document_animation_samples(document)
		if layers.len == 0 || !storage.contains(layers.data) {
			return layers
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owned := []BackgroundLayerData{cap: layers.len}
		for layer in layers {
			owned << BackgroundLayerData{
				...layer
				image: layer.image.clone()
				position_x: owned_length_percentage(layer.position_x)
				position_y: owned_length_percentage(layer.position_y)
				size_x: owned_length_percentage_or_auto(layer.size_x)
				size_y: owned_length_percentage_or_auto(layer.size_y)
			}
		}
		return owned
	}
	return layers
}

// A copy that shares no storage with `value`. Calculations are parsed again
// from their serialization.
fn owned_length_percentage(value LengthPercentage) LengthPercentage {
	if !value.is_calculated() { return value }
	inner := value.calculated()
	parsed := parse_css_value_logic(.width, inner.serialization.clone()) or {
		return LengthPercentage.from_length(Length.make_px(0))
	}
	return LengthPercentage.from_style_value_logic(parsed)
}

fn owned_length_percentage_or_auto(value LengthPercentageOrAuto) LengthPercentageOrAuto {
	length_percentage := value.length_percentage_ or { return LengthPercentageOrAuto.make_auto() }
	return LengthPercentageOrAuto{
		length_percentage_: owned_length_percentage(length_percentage)
	}
}

// A style value that outlives its sample: transitions keep their start and
// end values for their whole duration. Copy samples into ordinary storage by
// parsing their text again, so the copy keeps a typed value for the
// keyframe computation.
fn (s &StyleComputer) copy_sampled_style_value(property_id PropertyID, value &dom.StyleValue) &dom.StyleValue {
	if s.animation_samples_ == unsafe { nil } || !s.animation_samples_.contains(voidptr(value)) {
		return unsafe { value }
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	text := value.css_text.clone()
	mut working_copy := parse_css_value(ParsingParams{}, text, property_id) or {
		&dom.StyleValue{
			css_text: text
		}
	}
	if url := value.base_url {
		working_copy.base_url = url.clone()
	}
	return working_copy
}
