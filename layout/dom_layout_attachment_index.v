module layout

import dom

// TreeBuilder already assigns dense preorder ranges, including text nodes.
// A fresh pointer table preserves the attachment's visited-before-use rule
// without growing and hashing an address map twice per geometry pass.
struct DOMLayoutAttachmentIndex {
	order &LayoutTreeOrder = unsafe { nil }
	start u32
mut:
	slots []&dom.LayoutNode
	other map[u64]&dom.LayoutNode
}

fn DOMLayoutAttachmentIndex.new(root &Node) DOMLayoutAttachmentIndex {
	if root.tree_order_ != unsafe { nil } && root.tree_order_.valid
		&& root.tree_order_owner_ == voidptr(root) {
		return DOMLayoutAttachmentIndex{
			order: root.tree_order_
			start: root.tree_order_start_
			slots: []&dom.LayoutNode{len:int(root.tree_order_end_ - root.tree_order_start_), init:unsafe { nil }}
		}
	}
	return DOMLayoutAttachmentIndex{}
}

fn (index &DOMLayoutAttachmentIndex) slot(node &Node) ?int {
	if index.order != unsafe { nil } && voidptr(index.order) == voidptr(node.tree_order_)
		&& node.tree_order_owner_ == voidptr(node) && node.tree_order_start_ >= index.start {
		position := node.tree_order_start_ - index.start
		if position < u32(index.slots.len) { return int(position) }
	}
	return none
}

fn (mut index DOMLayoutAttachmentIndex) set(node &Node, mirror &dom.LayoutNode) {
	if position := index.slot(node) {
		index.slots[position] = mirror
	} else {
		index.other[u64(voidptr(node))] = mirror
	}
}

fn (index &DOMLayoutAttachmentIndex) get(node &Node) ?&dom.LayoutNode {
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
