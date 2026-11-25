module layout

import dom
import platform

// TreeBuilder already assigns dense preorder ranges, including text nodes.
// The pointer table and cached inline pieces are private to one traversal.
// Published DOM mirrors and their geometry continue to use document storage.
struct DOMLayoutAttachmentWorkspace {
	order &LayoutTreeOrder = unsafe { nil }
	start u32
mut:
	arena &platform.Arena = unsafe { nil }
	slots []&dom.LayoutNode
	other map[u64]&dom.LayoutNode
	inline_pieces map[u64][]InlineBoxPiece
}

fn DOMLayoutAttachmentWorkspace.new(root &Node) DOMLayoutAttachmentWorkspace {
	mut arena := unsafe { &platform.Arena(nil) }
	mut entry := platform.ArenaEntry{}
	$if prealloc {
		if platform.current_retained_arena() != unsafe { nil } {
			arena = platform.new_arena('DOM layout attachment')
			entry = arena.enter()
		}
	}
	defer { if arena != unsafe { nil } { arena.leave(entry) } }
	if root.tree_order_ != unsafe { nil } && root.tree_order_.valid
		&& root.tree_order_owner_ == voidptr(root) {
		return DOMLayoutAttachmentWorkspace{
			order: root.tree_order_
			start: root.tree_order_start_
			arena: arena
			slots: []&dom.LayoutNode{len:int(root.tree_order_end_ - root.tree_order_start_), init:unsafe { nil }}
		}
	}
	return DOMLayoutAttachmentWorkspace{arena: arena}
}

fn (mut index DOMLayoutAttachmentWorkspace) finish() {
	if index.arena != unsafe { nil } {
		if incremental_layout_diagnostics {
			usage := index.arena.usage()
			eprintln('VOX_DOM_ATTACHMENT_WORKSPACE used=${usage.used} slots=${index.slots.len} inline_containers=${index.inline_pieces.len}')
		}
		index.arena.release()
		index.arena = unsafe { nil }
	}
}

fn (index &DOMLayoutAttachmentWorkspace) slot(node &Node) ?int {
	if index.order != unsafe { nil } && voidptr(index.order) == voidptr(node.tree_order_)
		&& node.tree_order_owner_ == voidptr(node) && node.tree_order_start_ >= index.start {
		position := node.tree_order_start_ - index.start
		if position < u32(index.slots.len) { return int(position) }
	}
	return none
}

fn (mut index DOMLayoutAttachmentWorkspace) set(node &Node, mirror &dom.LayoutNode) {
	if position := index.slot(node) {
		index.slots[position] = mirror
		return
	}
	mut entry := platform.ArenaEntry{}
	if index.arena != unsafe { nil } { entry = index.arena.enter() }
	index.other[u64(voidptr(node))] = mirror
	if index.arena != unsafe { nil } { index.arena.leave(entry) }
}

fn (index &DOMLayoutAttachmentWorkspace) get(node &Node) ?&dom.LayoutNode {
	if position := index.slot(node) {
		mirror := index.slots[position]
		if mirror != unsafe { nil } && mirror.layout_handle == voidptr(node) { return mirror }
		return none
	}
	if mirror := index.other[u64(voidptr(node))] { return mirror }
	// Public attachment helpers also accept unindexed trees and value copies.
	// If a callback reindexes an already visited node, its old slot still owns
	// the recorded association, just as an address map would.
	for mirror in index.slots {
		if mirror != unsafe { nil } && mirror.layout_handle == voidptr(node) { return mirror }
	}
	return none
}
