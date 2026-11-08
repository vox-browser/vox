module css

import dom
import math
import os
import platform
import sync
import sync.stdatomic

const disable_scalar_dom_box_reuse = os.getenv('VOX_DISABLE_SCALAR_DOM_BOX_REUSE') != ''
const scalar_dom_box_reuse_diagnostics = os.getenv('VOX_SCALAR_DOM_BOX_REUSE_DIAGNOSTICS') != ''
const scalar_dom_box_slot_count = 4096

@[heap]
struct ScalarDOMBox {
	key u64
	value &dom.StyleValue
}

// Scalar payloads contain no document, URL or component owners. This bounded
// immutable table retains only their independent typed box and serialized text.
// Each caller still gets its own mutable DOM bridge (including base_url).
__global scalar_dom_boxes_ [scalar_dom_box_slot_count]&ScalarDOMBox
__global scalar_dom_box_mutex_ &sync.Mutex = sync.new_mutex()
__global scalar_dom_box_reported bool

fn scalar_dom_quantized_number(raw f64) ?u32 {
	if raw != raw || raw < -16 || raw > 1024 { return none }
	if raw == 0 && math.f64_bits(raw) != 0 { return none }
	quantized := i64(raw * 64)
	if raw != f64(quantized) / 64 { return none }
	return u32(quantized + 1024)
}

fn scalar_dom_box_key(value &StyleValue) ?u64 {
	match value {
		KeywordStyleValue { return (u64(1) << 32) | u64(value.keyword_) }
		LengthStyleValue {
			if value.length_.unit_ != .px { return none }
			return (u64(2) << 32) | u64(scalar_dom_quantized_number(value.length_.value_)?)
		}
		NumberStyleValue { return (u64(3) << 32) | u64(scalar_dom_quantized_number(value.value_)?) }
		IntegerStyleValue {
			if value.value_ < -16 || value.value_ > 1024 { return none }
			return (u64(4) << 32) | u64(value.value_ + 16)
		}
		PercentageStyleValue { return (u64(5) << 32) | u64(scalar_dom_quantized_number(value.percentage_.value())?) }
		ColorStyleValue {
			color := value.color_
			return (u64(6) << 32) | (u64(color.r) << 24) | (u64(color.g) << 16) | (u64(color.b) << 8) | u64(color.a)
		}
		else { return none }
	}
}

fn reusable_scalar_dom_box(value &StyleValue) ?&ScalarDOMBox {
	if disable_scalar_dom_box_reuse || scalar_dom_box_mutex_ == unsafe { nil } { return none }
	key := scalar_dom_box_key(value) or { return none }
	mut mixed := u32(key)
	mixed = (mixed ^ (mixed >> 16)) * u32(0x7feb352d)
	mixed = (mixed ^ (mixed >> 15)) * u32(0x846ca68b)
	index := int((mixed ^ (mixed >> 16) ^ u32(key >> 32) * u32(547)) & u32(scalar_dom_box_slot_count - 1))
	// The typed global array remains a GC root. Atomic publication allows a
	// hit without taking the insertion mutex; entries never change or retire.
	slot := unsafe { &u64(voidptr(&scalar_dom_boxes_[index])) }
	address := stdatomic.load_u64(slot)
	if address != 0 {
		entry := unsafe { &ScalarDOMBox(voidptr(address)) }
		if entry.key != key { return none }
		report_scalar_dom_box_reuse()
		return entry
	}
	scalar_dom_box_mutex_.lock()
	defer { scalar_dom_box_mutex_.unlock() }
	current_address := stdatomic.load_u64(slot)
	if current_address != 0 {
		entry := unsafe { &ScalarDOMBox(voidptr(current_address)) }
		if entry.key != key { return none }
		return entry
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if !platform.arena_thread_is_current() { platform.retain_thread_allocations() }
	// Reconstruct the supported scalar in this owner; its producer may be in
	// scratch. The private bridge is never returned for a caller to mutate.
	owned := export_property_value(*value)
	entry := &ScalarDOMBox{key: key, value: dom_style_value_from_value_logic_uncached(owned)}
	stdatomic.store_u64(slot, u64(voidptr(entry)))
	return entry
}

fn report_scalar_dom_box_reuse() {
	if scalar_dom_box_reuse_diagnostics && !scalar_dom_box_reported {
		scalar_dom_box_reported = true
		eprintln('Vox scalar DOM boxes: reused immutable typed payload and serialization')
	}
}
