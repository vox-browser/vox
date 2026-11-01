module layout

import os

const disable_retained_font_validation = os.getenv('VOX_DISABLE_RETAINED_FONT_VALIDATION') != ''
const retained_font_validation_diagnostics = os.getenv('VOX_RETAINED_FONT_VALIDATION_DIAGNOSTICS') != ''

__global retained_font_validation_reported bool

struct RetainedFontValidation {
mut:
	generation u64
	valid      bool
}

// The caller first checks the complete style/tree/space inputs. FontComputer
// advances its generation for face, display-period, cache and policy changes.
// A successful comparison therefore remains valid until that generation moves.
// Keep the original cascade and metrics immutable for the next comparison.
fn (mut validation RetainedFontValidation) matches(inputs []RetainedInlineInput,
	captured_generation u64, current_generation u64) bool {
	if captured_generation == current_generation { return true }
	if !disable_retained_font_validation && validation.valid
		&& validation.generation == current_generation {
		if retained_font_validation_diagnostics && !retained_font_validation_reported {
			retained_font_validation_reported = true
			eprintln('Vox retained font validation: reused current generation')
		}
		return true
	}
	if !retained_layout_fonts_are_current(inputs) { return false }
	if !disable_retained_font_validation {
		validation.generation = current_generation
		validation.valid = true
	}
	return true
}

fn (cached &RetainedInlineLayout) fonts_are_current(generation u64) bool {
	mut mutable := unsafe { &RetainedInlineLayout(cached) }
	return mutable.font_validation_.matches(cached.inputs, cached.font_generation, generation)
}

fn (cached &RetainedBlockLayout) fonts_are_current(generation u64) bool {
	mut mutable := unsafe { &RetainedBlockLayout(cached) }
	return mutable.font_validation_.matches(cached.inputs, cached.font_generation, generation)
}
