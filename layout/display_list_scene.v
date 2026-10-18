module layout

import dom
import platform

// Storage of one published display list: its command vector and everything a
// recording allocates for those commands (visual layer and clip lists, the
// DisplayList handle). Recording reads retained state (paint tree, visual
// contexts, per-phase command caches) and copies it shallowly, so a scene may
// point into that state but nothing outside the scene points into it.
//
// The document's layout result holds one reference to its current scene;
// every consumer that keeps the commands (the shell between frames) holds
// another. When the last reference goes, the arena is reset and reused for a
// later recording. Without -prealloc the arena is inert and the collector
// reclaims scenes.
@[heap]
pub struct DisplayListScene {
mut:
	arena      &platform.Arena       = unsafe { nil }
	references int
	pool       &DisplayListScenePool = unsafe { nil }
	// The document's paint_scene_generation when this scene was recorded.
	generation u64
}

// Per-document scenes, carried from one layout result to the next.
@[heap]
struct DisplayListScenePool {
mut:
	document &dom.Document = unsafe { nil }
	free     []&DisplayListScene
	// Scenes still referenced by the layout result or a consumer.
	live []&DisplayListScene
	// A hosting document copies this document's commands into its own paint
	// transport (nested viewports), which outlives any one of our scenes.
	// Such documents record into ordinary storage.
	borrowed bool
}

// A reset scene is kept for the next recording; a couple of spares cover a
// consumer that still holds the previous one.
const display_list_scene_spares = 2

fn (mut pool DisplayListScenePool) acquire() &DisplayListScene {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut scene := if pool.free.len > 0 {
		pool.free.pop()
	} else {
		&DisplayListScene{
			arena: platform.new_arena('display list scene')
			pool:  pool
		}
	}
	scene.references = 1
	if pool.document != unsafe { nil } {
		mut document := pool.document
		document.paint_scene_generation++
		scene.generation = document.paint_scene_generation
	}
	pool.live << scene
	pool.publish_oldest_live_generation()
	return scene
}

// Tell the document which recordings may still be read: rendering-update
// storage referenced only by older scenes can be reused.
fn (mut pool DisplayListScenePool) publish_oldest_live_generation() {
	if pool.document == unsafe { nil } {
		return
	}
	mut document := pool.document
	mut oldest := document.paint_scene_generation + 1
	for scene in pool.live {
		if scene.generation < oldest {
			oldest = scene.generation
		}
	}
	document.oldest_live_paint_scene_generation = oldest
}

fn (mut scene DisplayListScene) retain() {
	scene.references++
}

fn (mut scene DisplayListScene) release() {
	scene.references--
	if scene.references > 0 {
		return
	}
	if scene.references < 0 {
		panic('display list scene released too often')
	}
	mut arena := scene.arena
	mut pool := scene.pool
	for index, live in pool.live {
		if voidptr(live) == voidptr(scene) {
			pool.live.delete(index)
			break
		}
	}
	pool.publish_oldest_live_generation()
	if pool.free.len >= display_list_scene_spares {
		arena.release()
		return
	}
	arena.reset()
	persistent := platform.enter_persistent()
	pool.free << scene
	platform.leave_persistent(persistent)
}

fn (mut result DocumentLayoutResult) scene_pool_() &DisplayListScenePool {
	if result.scene_pool == unsafe { nil } {
		persistent := platform.enter_persistent()
		result.scene_pool = &DisplayListScenePool{
			document: result.document
		}
		platform.leave_persistent(persistent)
	}
	return result.scene_pool
}

// The layout result stops publishing its current scene: invalidation or a
// replacement result. Consumers that retained it keep it alive.
fn (mut result DocumentLayoutResult) drop_display_list_scene() {
	result.display_list_commands = []PaintCommand{}
	result.display_list = unsafe { nil }
	mut scene := result.scene
	result.scene = unsafe { nil }
	if scene != unsafe { nil } {
		scene.release()
	}
}

// A replacement result takes over publishing. The replaced result keeps its
// commands for holders of its display list; under -prealloc only a holder
// that retained the scene keeps them valid, so with none left they are
// dropped together with the storage.
fn (mut result DocumentLayoutResult) retire_display_list_scene() {
	mut scene := result.scene
	result.scene = unsafe { nil }
	if scene == unsafe { nil } {
		return
	}
	$if prealloc {
		if scene.references <= 1 {
			result.display_list_commands = []PaintCommand{}
			result.display_list = unsafe { nil }
		}
	}
	scene.release()
}

// retain_display_list_scene keeps the storage behind `display_list`'s current
// commands alive until release_display_list_scene. It returns nil when the
// list has no scene of its own.
pub fn retain_display_list_scene(display_list &dom.DisplayList) voidptr {
	if display_list == unsafe { nil } || display_list.concrete_handle == unsafe { nil } {
		return unsafe { nil }
	}
	result := viewport_layout_result(display_list.concrete_handle)
	mut scene := result.scene
	if scene == unsafe { nil } {
		return unsafe { nil }
	}
	scene.retain()
	return voidptr(scene)
}

pub fn release_display_list_scene(handle voidptr) {
	if handle == unsafe { nil } {
		return
	}
	mut scene := unsafe { &DisplayListScene(handle) }
	scene.release()
}

// The hosted document's commands are copied into a host's paint transport.
fn mark_display_list_scenes_borrowed(document &dom.Document) {
	mut result := document_layout_result(document) or { return }
	mut pool := result.scene_pool_()
	pool.borrowed = true
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.paint_borrowed_by_host = true
}

// record_retained_display_list records `document` and keeps the scene behind
// the returned list alive for the rest of the process. Tests use it to compare
// lists from different recordings.
pub fn record_retained_display_list(mut document dom.Document) ?&dom.DisplayList {
	display_list := document.record_display_list()?
	_ = retain_display_list_scene(display_list)
	return display_list
}
