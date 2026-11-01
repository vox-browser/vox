module layout

import dom

// Relayout replaces DocumentLayoutResult, but not the document's recording
// owner. Move only its private workspace; published lists retain their own
// immutable command vectors and the shell's current vector stays in use.
fn take_document_recording_scratch(document &dom.Document) CompatibilityRecordScratch {
	mut previous := document_layout_result(document) or { return CompatibilityRecordScratch{} }
	mut scratch := unsafe { previous.record_scratch }
	previous.record_scratch = CompatibilityRecordScratch{}
	// The previous tree can now be retired even if the next recording needs a
	// smaller plan. Preserve capacity without retaining obsolete box pointers.
	for mut step in scratch.plan {
		step = CompatibilityCachedVisualReplayStep{}
	}
	scratch.plan.clear()
	for mut context in scratch.memo_contexts {
		context = CompatibilityFlattenedVisualContext{}
	}
	scratch.memo_contexts.clear()
	scratch.viewport_ink_cache.invalidate()
	return scratch
}
