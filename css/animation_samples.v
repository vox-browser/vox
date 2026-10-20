module css

import dom
import platform

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
// Hosted documents whose display lists are copied into a parent (nested
// viewports) and builds without -prealloc keep samples in ordinary storage.

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
	spare_target_lists  [][]AnimationSampleTarget
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

fn (mut s StyleComputer) animation_sample_storage() &AnimationSampleStorage {
	$if prealloc {
		if s.document_ == unsafe { nil } || s.document_.paint_borrowed_by_host {
			return unsafe { nil }
		}
		if s.animation_samples_ == unsafe { nil } {
			persistent := platform.enter_persistent()
			s.animation_samples_ = &AnimationSampleStorage{}
			platform.leave_persistent(persistent)
		}
		return s.animation_samples_
	}
	return unsafe { nil }
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
	limit := if animation_sample_arena_updates * storage.update_bytes > animation_sample_arena_bytes {
		animation_sample_arena_updates * storage.update_bytes
	} else {
		animation_sample_arena_bytes
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
		storage.spare_target_lists.pop()
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
				storage.spare_target_lists << targets
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
	for target in retiring.targets {
		if retiring.element_style_references_arena(target.element) {
			return true
		}
		if target.inherited
			&& retiring.descendant_styles_reference_arena(target.element.element().as_node()) {
			return true
		}
	}
	return false
}

// The element's style, the style its layout node last applied, and its
// animated custom-property overlay.
fn (retiring &RetiringAnimationSamples) element_style_references_arena(target dom.AbstractElement) bool {
	if dom_computed := target.computed_properties() {
		if retiring.arena.contains(voidptr(dom_computed)) {
			return true
		}
		if computed := computed_properties_from_dom(dom_computed) {
			if retiring.computed_references_arena(computed) {
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
				if retiring.computed_references_arena(computed) {
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

fn (retiring &RetiringAnimationSamples) descendant_styles_reference_arena(node &dom.Node) bool {
	mut child := node.first_child()
	for {
		current := child or { break }
		if element := current.as_element() {
			if retiring.element_style_references_arena(dom.AbstractElement.new(element, none))
				|| retiring.element_style_references_arena(dom.AbstractElement.new(element, dom.PseudoElement.before))
				|| retiring.element_style_references_arena(dom.AbstractElement.new(element, dom.PseudoElement.after)) {
				return true
			}
		}
		if retiring.descendant_styles_reference_arena(current) {
			return true
		}
		child = current.next_sibling()
	}
	return false
}

fn (retiring &RetiringAnimationSamples) value_references_arena(value &dom.StyleValue) bool {
	return value != unsafe { nil } && (retiring.arena.contains(voidptr(value))
		|| retiring.arena.contains(voidptr(value.css_text.str))
		|| retiring.arena.contains(value.css_value_handle))
}

// Whether any value of `computed`, or its materialized layout snapshot, is
// stored in the arena. Values are checked with their text, which other values
// can share as slices. The snapshot is scanned word by word: it holds copies of
// typed values whose own pointers may lead into a sample.
fn (retiring &RetiringAnimationSamples) computed_references_arena(computed &ComputedProperties) bool {
	// Fields materialized outside the snapshot, such as content and list
	// markers, are rewritten by each resolve like the snapshot itself.
	if retiring.struct_references_arena(voidptr(computed), int(sizeof(ComputedProperties))) {
		return true
	}
	for index in 0 .. computed.raw_property_count() {
		if retiring.value_references_arena(computed.raw_property_at_index(index)) {
			return true
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
	return false
}

// Scan a struct's words for pointers into the arena.
fn (retiring &RetiringAnimationSamples) struct_references_arena(start voidptr, size int) bool {
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
	mut copy := &dom.StyleValue{
		css_text: value.css_text.clone()
	}
	if url := value.base_url {
		copy.base_url = url.clone()
	}
	return copy
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
	inner := value.value_
	return match inner {
		Length { LengthPercentage.from_length(Length.new(inner.value_, inner.unit_)) }
		Percentage { LengthPercentage.from_percentage(Percentage.new(inner.value())) }
		CalculatedStyleValue {
			parsed := parse_css_value_logic(.width, inner.serialization.clone()) or {
				return LengthPercentage.from_length(Length.make_px(0))
			}
			LengthPercentage.from_style_value_logic(parsed)
		}
	}
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
	mut copy := parse_css_value(ParsingParams{}, text, property_id) or {
		&dom.StyleValue{
			css_text: text
		}
	}
	if url := value.base_url {
		copy.base_url = url.clone()
	}
	return copy
}
