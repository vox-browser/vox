module css

import os
import sync.stdatomic

const retain_animation_sample_property_scan = os.getenv('VOX_RETAIN_ANIMATION_SAMPLE_PROPERTY_SCAN') != ''
const animation_sample_property_diagnostics = os.getenv('VOX_ANIMATION_SAMPLE_PROPERTY_DIAGNOSTICS') != ''
const retain_animation_sample_computed_scan = os.getenv('VOX_RETAIN_ANIMATION_SAMPLE_COMPUTED_SCAN') != ''
const animation_sample_computed_diagnostics = os.getenv('VOX_ANIMATION_SAMPLE_COMPUTED_DIAGNOSTICS') != ''

__global animation_sample_property_scan_reported stdatomic.AtomicVal[bool]
__global animation_sample_computed_scan_reported stdatomic.AtomicVal[bool]

// One synchronous, read-only inspection of one settled retiring arena. Shared
// property pages need inspecting only once during that call. Nothing invokes
// author code or changes styles while the inspector walks them. V can promote
// this record to the heap, so its caller supplies a temporary allocation scope
// and releases it before returning. Pages and their values can change between
// inspections, including when their addresses stay the same.
struct AnimationSampleReferenceScan {
	retiring           &RetiringAnimationSamples
	use_property_pages bool = !retain_animation_sample_property_scan
	use_clean_computed bool = !retain_animation_sample_computed_scan
mut:
	clean_pages [256]voidptr
	clean_computed [256]voidptr
}

fn animation_sample_computed_scan_slot(computed &ComputedProperties) int {
	address := u64(voidptr(computed))
	return int(((address >> 4) ^ (address >> 12)) & 255)
}

fn animation_sample_page_scan_slot(page &ComputedPropertyPage) int {
	address := u64(voidptr(page))
	return int(((address >> 4) ^ (address >> 12)) & 255)
}

fn (mut scan AnimationSampleReferenceScan) property_page_references_arena(page &ComputedPropertyPage, count int) bool {
	slot := animation_sample_page_scan_slot(page)
	if scan.clean_pages[slot] == voidptr(page) {
		if animation_sample_property_diagnostics
			&& animation_sample_property_scan_reported.compare_and_swap(false, true) {
			eprintln('Vox animation retirement: reused clean property page within inspection')
		}
		return false
	}
	for index in 0 .. count {
		if scan.retiring.value_references_arena(page.values[index]) { return true }
	}
	// Only full pages enter the memo. A partial final page can share an address
	// with a page used earlier in a store, where more slots must be inspected.
	if count == computed_property_page_size { scan.clean_pages[slot] = voidptr(page) }
	return false
}
