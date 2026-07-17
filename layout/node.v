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
	// Concrete-type discriminants (C++ uses virtual fast_is<T>(); V has no RTTI). Each subclass's
	// constructor sets its flags; a flag is true for the type AND its subclasses (is_box_ is set for
	// Box and BlockContainer, etc.).
	is_box_             bool
	is_block_container_ bool
	is_text_node_       bool
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

// --- NodeWithStyleAndBoxModelMetrics (Layout/Node.h) ---
//
// A styled node that participates in the box model. C++ also stores box-model metrics here, but current
// Ladybird keeps the used margin/padding/border values in LayoutState::UsedValues, so this type is thin.
@[heap]
pub struct NodeWithStyleAndBoxModelMetrics {
	NodeWithStyle
pub mut:
	continuation_of_node_ ?&NodeWithStyleAndBoxModelMetrics
}

pub fn (n &NodeWithStyleAndBoxModelMetrics) continuation_of_node() ?&NodeWithStyleAndBoxModelMetrics {
	return n.continuation_of_node_
}

// --- Box (Layout/Box.h) : NodeWithStyleAndBoxModelMetrics ---
//
// A box in the layout tree. The used geometry (content size, offsets) lives in LayoutState::UsedValues;
// the persistent Box holds intrinsic-size caches (added later), out-of-flow abspos children, and the
// natural (intrinsic) size for replaced elements.
@[heap]
pub struct Box {
	NodeWithStyleAndBoxModelMetrics
pub mut:
	contained_abspos_children_ []&Node
}

pub fn Box.new(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) &Box {
	return &Box{
		NodeWithStyleAndBoxModelMetrics: NodeWithStyleAndBoxModelMetrics{
			NodeWithStyle: NodeWithStyle{
				Node:             Node{
					document_:  document
					dom_node_:  dom_node
					has_style_: true
					is_box_:    true
				}
				computed_values_: computed_values
			}
		}
	}
}

pub fn (n &Box) contained_abspos_children() []&Node {
	return n.contained_abspos_children_
}

pub fn (mut n Box) add_contained_abspos_child(child &Node) {
	n.contained_abspos_children_ << child
}

pub fn (n &Node) is_box() bool {
	return n.is_box_
}

pub fn (n &Node) as_box() ?&Box {
	if !n.is_box_ {
		return none
	}
	return unsafe { &Box(n) }
}

// --- BlockContainer (Layout/BlockContainer.h) : Box ---
//
// A box that contains either only block-level boxes or only inline-level boxes (a block container).
@[heap]
pub struct BlockContainer {
	Box
}

pub fn BlockContainer.new(document &dom.Document, dom_node ?&dom.Node, computed_values &css.ComputedProperties) &BlockContainer {
	return &BlockContainer{
		Box: Box{
			NodeWithStyleAndBoxModelMetrics: NodeWithStyleAndBoxModelMetrics{
				NodeWithStyle: NodeWithStyle{
					Node:             Node{
						document_:           document
						dom_node_:           dom_node
						has_style_:          true
						is_box_:             true
						is_block_container_: true
					}
					computed_values_: computed_values
				}
			}
		}
	}
}

pub fn (n &Node) is_block_container() bool {
	return n.is_block_container_
}

pub fn (n &Node) as_block_container() ?&BlockContainer {
	if !n.is_block_container_ {
		return none
	}
	return unsafe { &BlockContainer(n) }
}

// --- TextNode (Layout/TextNode.h) : Node ---
//
// A layout node for a DOM text node. Unlike element boxes it has no independent style (it uses its
// parent's), so it embeds Node directly rather than NodeWithStyle. It holds the whitespace-processed text.
@[heap]
pub struct TextNode {
	Node
pub mut:
	text_for_rendering_ string
}

pub fn TextNode.new(document &dom.Document, dom_text_node &dom.Node, text_for_rendering string) &TextNode {
	return &TextNode{
		Node:                Node{
			document_:     document
			dom_node_:     dom_text_node
			is_text_node_: true
		}
		text_for_rendering_: text_for_rendering
	}
}

// Layout::TextNode::text_for_rendering().
pub fn (n &TextNode) text_for_rendering() string {
	return n.text_for_rendering_
}

pub fn (n &Node) is_text_node() bool {
	return n.is_text_node_
}

pub fn (n &Node) as_text_node() ?&TextNode {
	if !n.is_text_node_ {
		return none
	}
	return unsafe { &TextNode(n) }
}

// Collapse runs of ASCII whitespace to single spaces (the white-space: normal case of
// TextNode::compute_text_for_rendering). FIXME: the full algorithm also honours white-space pre/nowrap/...,
// collapses leading/trailing whitespace across element boundaries, and preserves segment breaks.
pub fn collapse_whitespace(text string) string {
	mut result := []u8{}
	mut in_whitespace := false
	for c in text {
		if c == ` ` || c == `\t` || c == `\n` || c == `\r` || c == `\f` {
			if !in_whitespace {
				result << ` `
				in_whitespace = true
			}
		} else {
			result << c
			in_whitespace = false
		}
	}
	return result.bytestr()
}
