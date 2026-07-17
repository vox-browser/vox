module layout

import dom
import css

// Translation of Ladybird's Layout::Node (Layout/Node.h) — the base of the layout tree. In C++ Node is
// a JS::Cell + TreeNode<Node>; here the tree is modelled with a parent pointer + children array (as this
// port's DOM::Node is), rather than C++ TreeNode's intrusive first-child/next-sibling linked list.
//
// This replaces the `{ stub LayoutStub }` shell. NodeWithStyle / Box / BlockContainer etc. remain shells
// for now and will build on this base in later slices.
@[heap]
pub struct Node {
pub mut:
	// Tree structure.
	parent_   ?&Node
	children_ []&Node
	// Layout::Node members (Layout/Node.h).
	document_                    &dom.Document = unsafe { nil }
	dom_node_                    ?&dom.Node
	pseudo_element_generator_    ?&dom.Element
	generated_for_               ?dom.PseudoElement
	anonymous_                   bool
	has_style_                   bool
	children_are_inline_         bool
	is_flex_item_                bool
	is_grid_item_                bool
	is_body_                     bool
	needs_layout_update_         bool
	initial_quote_nesting_level_ u32
}

// Node(DOM::Document&, DOM::Node*) — a layout node for `dom_node` (null for anonymous boxes).
pub fn Node.new(document &dom.Document, dom_node ?&dom.Node) &Node {
	return &Node{
		document_: document
		dom_node_: dom_node
	}
}

// Whether two layout nodes are the same object (pointer identity — V's `&Node == &Node` compares by value).
pub fn layout_nodes_same(a &Node, b &Node) bool {
	return voidptr(a) == voidptr(b)
}

// --- Tree structure ---

// TreeNode<Node>::append_child — append `child` as this node's last child.
pub fn (mut n Node) append_child(child &Node) {
	mut mutable_child := unsafe { &Node(child) }
	mutable_child.parent_ = n
	n.children_ << child
}

pub fn (n &Node) parent() ?&Node {
	return n.parent_
}

pub fn (n &Node) children() []&Node {
	return n.children_
}

pub fn (n &Node) has_children() bool {
	return n.children_.len > 0
}

pub fn (n &Node) child_count() int {
	return n.children_.len
}

pub fn (n &Node) first_child() ?&Node {
	if n.children_.len == 0 {
		return none
	}
	return n.children_[0]
}

pub fn (n &Node) last_child() ?&Node {
	if n.children_.len == 0 {
		return none
	}
	return n.children_[n.children_.len - 1]
}

pub fn (n &Node) next_sibling() ?&Node {
	parent := n.parent_ or { return none }
	for i, child in parent.children_ {
		if layout_nodes_same(child, n) {
			if i + 1 < parent.children_.len {
				return parent.children_[i + 1]
			}
			return none
		}
	}
	return none
}

pub fn (n &Node) previous_sibling() ?&Node {
	parent := n.parent_ or { return none }
	for i, child in parent.children_ {
		if layout_nodes_same(child, n) {
			if i > 0 {
				return parent.children_[i - 1]
			}
			return none
		}
	}
	return none
}

// --- Layout::Node accessors (Layout/Node.h) ---

pub fn (n &Node) dom_node() ?&dom.Node {
	return n.dom_node_
}

pub fn (n &Node) document() &dom.Document {
	return n.document_
}

pub fn (n &Node) is_anonymous() bool {
	return n.anonymous_
}

pub fn (n &Node) has_style() bool {
	return n.has_style_
}

pub fn (n &Node) children_are_inline() bool {
	return n.children_are_inline_
}

pub fn (mut n Node) set_children_are_inline(value bool) {
	n.children_are_inline_ = value
}

pub fn (n &Node) is_flex_item() bool {
	return n.is_flex_item_
}

pub fn (n &Node) is_grid_item() bool {
	return n.is_grid_item_
}

pub fn (n &Node) is_body() bool {
	return n.is_body_
}

pub fn (n &Node) needs_layout_update() bool {
	return n.needs_layout_update_
}

pub fn (mut n Node) set_needs_layout_update(value bool) {
	n.needs_layout_update_ = value
}

pub fn (n &Node) generated_for_pseudo_element() ?dom.PseudoElement {
	return n.generated_for_
}

pub fn (n &Node) initial_quote_nesting_level() u32 {
	return n.initial_quote_nesting_level_
}

// --- NodeWithStyle (Layout/Node.h) ---
//
// A layout node that has a computed style. C++ stores a resolved CSS::ComputedValues; this port holds a
// reference to the css.ComputedProperties (the resolved property map the port already produces via the
// StyleComputer), which exposes the layout-facing accessors (display(), overflow_x(), ...).
@[heap]
pub struct NodeWithStyle {
	Node
pub mut:
	computed_values_ &css.ComputedProperties = unsafe { nil }
	layout_index_    u32
}

pub fn NodeWithStyle.new(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) &NodeWithStyle {
	return &NodeWithStyle{
		Node:             Node{
			document_:  document
			dom_node_:  dom_node
			has_style_: true
		}
		computed_values_: computed_values
	}
}

pub fn (n &NodeWithStyle) computed_values() &css.ComputedProperties {
	return n.computed_values_
}

pub fn (mut n NodeWithStyle) set_computed_values(computed_values &css.ComputedProperties) {
	n.computed_values_ = computed_values
}

pub fn (n &NodeWithStyle) layout_index() u32 {
	return n.layout_index_
}

// Cast a &Node to &NodeWithStyle. Layout::Node is abstract in C++ (every concrete layout node is a
// NodeWithStyle or below), so a styled node embeds Node at offset 0 and this reinterpret is valid.
pub fn (n &Node) as_node_with_style() ?&NodeWithStyle {
	if !n.has_style_ {
		return none
	}
	return unsafe { &NodeWithStyle(n) }
}
