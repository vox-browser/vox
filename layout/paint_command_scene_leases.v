module layout

import dom
import platform

struct HostedDisplayList {
	commands []PaintCommand
	scene    &DisplayListScene = unsafe { nil }
}

// A host can record inside its own document or projection arena. Switch to
// the child's owner while updating the child, then return to the host before
// copying the command vector. The child scene must never depend on allocations
// accidentally made in a shorter-lived parent workspace.
fn retain_hosted_display_list(document &dom.Document, width f64, height f64) ?HostedDisplayList {
	// A stale projection may still name a child closed during navigation.
	// Retained commands remain replayable, but a closed publisher cannot record
	// a replacement into storage whose document owner has already retired.
	if document.has_been_destroyed() { return none }
	mut owner := document.native_storage()
	mut allocations := if owner != unsafe { nil } {
		owner.enter_nested()
	} else {
		platform.RetainedArenaScope{}
	}
	defer { allocations.finish() }
	result := run_document_layout(document, width, height) or { return none }
	if result.root == unsafe { nil } { return none }
	mut child := unsafe { &dom.Document(document) }
	list := child.record_display_list() or { return none }
	return HostedDisplayList{
		commands: display_list_commands(list)
		scene: unsafe { &DisplayListScene(retain_display_list_scene(list)) }
	}
}

// Raw paint-command vectors and phase-cache buckets own one lease for each
// direct nested command. Copies used by replay only borrow those leases;
// a published DisplayListScene acquires its own deduplicated dependency set.
fn retain_paint_command_scenes(commands []PaintCommand) {
	for index in 0 .. commands.len {
		mut scene := commands[index].nested_viewport_scene
		if scene != unsafe { nil } { scene.retain() }
	}
}

// Release the complete raw vector returned by BlockBox.paint_commands once
// its consumer is done. Slices, clones and transformed commands borrow the
// original vector's leases and must not release them again. Commands obtained
// from a display list are instead owned by its retained DisplayListScene.
// Child scenes own all transitive nested leases, so do not walk into their
// nested_viewport_commands here.
pub fn release_paint_commands(commands []PaintCommand) {
	for index in 0 .. commands.len {
		mut scene := commands[index].nested_viewport_scene
		if scene != unsafe { nil } { scene.release() }
	}
}
