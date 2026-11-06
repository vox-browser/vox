module devtools

import dom
import math

pub const default_height = 300.0
pub const min_height = 120.0
pub const min_document_height = 80.0
pub const row_height = 18.0
pub const tree_padding = 4.0
pub const indent_width = 14.0
pub const expander_width = 14.0
// Double clicks open the inline editor, as in Chrome.
pub const double_click_ns = i64(450_000_000)
// A pathological expansion still renders a bounded native view tree.
const max_rows = 5000

pub enum RowKind {
	element
	close_tag
	text
	comment
	doctype
	shadow_root
	other
	editor
}

pub struct Row {
pub:
	node       i64
	depth      int
	kind       RowKind
	expandable bool
	expanded   bool
	segments   []Segment
}

pub fn (row Row) key() string {
	return if row.kind == .close_tag {
		'devtools-row-${row.node}-end'
	} else {
		'devtools-row-${row.node}'
	}
}

pub fn (row Row) columns() int {
	mut columns := 0
	for segment in row.segments {
		columns += segment.text.runes().len
	}
	return columns
}

pub fn (row Row) selectable() bool {
	return row.kind !in [.close_tag, .editor]
}

pub enum EditorKind {
	html
	text
}

pub struct Editor {
pub:
	node i64
	kind EditorKind
	text string
}

// DevTools is one tab's Elements panel. It refers to DOM nodes by unique ID
// and resolves them only through `nodes`, which `rebuild` fills from the live
// document, so a navigation never leaves it holding another document's nodes.
@[heap]
pub struct DevTools {
pub mut:
	open    bool
	height  f64 = default_height
	picking bool
	// Selected tree node; the node under the pointer in the tree or page.
	selected i64
	hovered  i64
	picked   i64
	expanded map[i64]bool
	editor   ?Editor
	error    string
	// The tree, rather than the page or a field, receives navigation keys.
	focused bool
	// Scroll the selected row into view after the next render.
	reveal  bool
	version u64
	rows    []Row
	nodes   map[i64]&dom.Node
	// Identity of the document the state above describes.
	document   voidptr
	generation int
	// Double-click detection for tree rows.
	click_node i64
	click_at   i64
	// The sidebar tab, and the selected element's styles as last collected
	// by the host.
	sidebar         SidebarTab
	styles          StyleSnapshot
	computed_filter string
	// Edit history for the current document.
	undo_stack []UndoEntry
	redo_stack []UndoEntry
	// The Console panel: messages for the current document, how many of the
	// host's messages were imported, and the prompt's history.
	panel                 Panel
	console               []ConsoleEntry
	console_seen          int
	console_reveal        bool
	console_history       []string
	console_history_index int
	// Host input state: the page element under the picker, whether the
	// pointer is over the panel, and a picker press whose release the page
	// must not see.
	picked_node         &dom.Node = unsafe { nil }
	pointer_in_pane     bool
	suppress_pointer_up bool
}

pub fn node_id(node &dom.Node) i64 {
	return node.unique_id().value()
}

// tree_parent is the parent shown in the tree; a shadow root hangs off its host.
pub fn tree_parent(node &dom.Node) ?&dom.Node {
	if parent := node.parent() {
		return parent
	}
	if shadow := node.as_shadow_root() {
		if host := shadow.host() {
			return host.as_node()
		}
	}
	return none
}

pub fn visible_children(node &dom.Node) []&dom.Node {
	mut result := []&dom.Node{}
	if element := node.as_element() {
		if shadow := element.shadow_root() {
			result << unsafe { &dom.Node(shadow) }
		}
	}
	for child in node.children {
		if !is_whitespace_text(child) {
			result << child
		}
	}
	return result
}

fn find_node(root &dom.Node, id i64) ?&dom.Node {
	if node_id(root) == id {
		return root
	}
	for child in visible_children(root) {
		if found := find_node(child, id) {
			return found
		}
	}
	return none
}

// sync resets per-document state when the tab shows a different document.
pub fn (mut tools DevTools) sync(document &dom.Document, generation int) bool {
	if voidptr(document) == tools.document && generation == tools.generation {
		return false
	}
	tools.document = voidptr(document)
	tools.generation = generation
	tools.selected = 0
	tools.hovered = 0
	tools.set_picked(none)
	tools.expanded = map[i64]bool{}
	tools.editor = none
	tools.error = ''
	tools.rows = []Row{}
	tools.nodes = map[i64]&dom.Node{}
	tools.styles = StyleSnapshot{}
	tools.undo_stack = []UndoEntry{}
	tools.redo_stack = []UndoEntry{}
	tools.console = []ConsoleEntry{}
	tools.console_seen = 0
	tools.click_node = 0
	tools.version++
	if document == unsafe { nil } {
		return true
	}
	// Chrome opens with <html> and <body> expanded and <body> selected.
	if root := document.document_element() {
		tools.expanded[node_id(root.as_node())] = true
		tools.selected = node_id(root.as_node())
	}
	if body := document.body() {
		node := unsafe { &dom.Node(body) }
		tools.expanded[node_id(node)] = true
		tools.selected = node_id(node)
	}
	return true
}

// rebuild flattens the expanded part of the document into rows.
pub fn (mut tools DevTools) rebuild(document &dom.Document) {
	tools.rows = []Row{cap: 64}
	tools.nodes = map[i64]&dom.Node{}
	if document == unsafe { nil } {
		return
	}
	root := unsafe { &dom.Node(document) }
	tools.nodes[node_id(root)] = root
	for child in visible_children(root) {
		tools.append_rows(child, 0)
	}
	if tools.selected != 0 && tools.row_index(tools.selected) < 0 {
		// Script can move the selection into a collapsed subtree.
		if node := find_node(root, tools.selected) {
			if tools.reveal_node(node) {
				tools.rows = []Row{cap: tools.rows.len}
				for child in visible_children(root) {
					tools.append_rows(child, 0)
				}
			}
		}
	}
	if tools.selected != 0 && tools.row_index(tools.selected) < 0 {
		tools.selected = 0
	}
	if editor := tools.editor {
		if editor.node !in tools.nodes {
			tools.editor = none
		}
	}
}

fn (mut tools DevTools) append_rows(node &dom.Node, depth int) {
	if tools.rows.len >= max_rows || is_whitespace_text(node) {
		return
	}
	id := node_id(node)
	tools.nodes[id] = node
	if editor := tools.editor {
		if editor.node == id {
			tools.rows << Row{
				node:  id
				depth: depth
				kind:  .editor
			}
			return
		}
	}
	if node.is_text() {
		tools.rows << Row{
			node:     id
			depth:    depth
			kind:     .text
			segments: [text_segment(node)]
		}
		return
	}
	if node.is_comment() {
		tools.rows << Row{
			node:     id
			depth:    depth
			kind:     .comment
			segments: [comment_segment(node)]
		}
		return
	}
	if node.is_document_type() {
		tools.rows << Row{
			node:     id
			depth:    depth
			kind:     .doctype
			segments: [doctype_segment(node)]
		}
		return
	}
	if element := node.as_element() {
		children := visible_children(node)
		mut segments := open_tag_segments(element)
		if children.len == 0 {
			if !is_void_element(element) {
				segments << close_tag_segment(element)
			}
			tools.rows << Row{
				node:     id
				depth:    depth
				kind:     .element
				segments: segments
			}
			return
		}
		if text := inline_text(children) {
			tools.nodes[node_id(text)] = text
			segments << Segment{shorten(text.text_content() or { '' }, inline_text_limit), color_text}
			segments << close_tag_segment(element)
			tools.rows << Row{
				node:     id
				depth:    depth
				kind:     .element
				segments: segments
			}
			return
		}
		expanded := tools.expanded[id] or { false }
		if !expanded {
			segments << Segment{'…', color_text}
			segments << close_tag_segment(element)
		}
		tools.rows << Row{
			node:       id
			depth:      depth
			kind:       .element
			expandable: true
			expanded:   expanded
			segments:   segments
		}
		if expanded {
			for child in children {
				tools.append_rows(child, depth + 1)
			}
			tools.rows << Row{
				node:     id
				depth:    depth
				kind:     .close_tag
				segments: [close_tag_segment(element)]
			}
		}
		return
	}
	if shadow := node.as_shadow_root() {
		children := visible_children(node)
		expanded := children.len > 0 && (tools.expanded[id] or { false })
		mode := if shadow.mode == .open { 'open' } else { 'closed' }
		tools.rows << Row{
			node:       id
			depth:      depth
			kind:       .shadow_root
			expandable: children.len > 0
			expanded:   expanded
			segments:   [Segment{'#shadow-root (${mode})', color_doctype}]
		}
		if expanded {
			for child in children {
				tools.append_rows(child, depth + 1)
			}
		}
		return
	}
	tools.rows << Row{
		node:     id
		depth:    depth
		kind:     .other
		segments: [Segment{node.node_name(), color_doctype}]
	}
}

// set_picked records the page element under the picker. It reports whether
// that changed.
pub fn (mut tools DevTools) set_picked(node ?&dom.Node) bool {
	target := node or { unsafe { nil } }
	if voidptr(target) == voidptr(tools.picked_node) {
		return false
	}
	tools.picked_node = target
	tools.picked = if target == unsafe { nil } { i64(0) } else { node_id(target) }
	return true
}

// highlight is the node the page outlines: the hovered tree row, otherwise
// the element under the picker.
pub fn (tools &DevTools) highlight() ?&dom.Node {
	if !tools.open {
		return none
	}
	if tools.hovered != 0 {
		return tools.node(tools.hovered)
	}
	if tools.picking && tools.picked_node != unsafe { nil } {
		return tools.picked_node
	}
	return none
}

pub fn (tools &DevTools) node(id i64) ?&dom.Node {
	return tools.nodes[id] or { return none }
}

pub fn (tools &DevTools) selected_node() ?&dom.Node {
	if tools.selected == 0 {
		return none
	}
	return tools.node(tools.selected)
}

// row_index is the selectable row of `id`, or -1.
pub fn (tools &DevTools) row_index(id i64) int {
	for index, row in tools.rows {
		if row.node == id && row.kind != .close_tag {
			return index
		}
	}
	return -1
}

pub fn (mut tools DevTools) select(id i64) {
	if id == 0 || id !in tools.nodes {
		return
	}
	tools.selected = id
	tools.error = ''
	tools.version++
}

// toggle expands or collapses a row. Collapsing a subtree that contains the
// selection moves the selection to the collapsed node, as Chrome does.
pub fn (mut tools DevTools) toggle(id i64) {
	node := tools.node(id) or { return }
	if tools.expanded[id] or { false } {
		tools.expanded.delete(id)
		if selected := tools.selected_node() {
			if contains(node, selected) {
				tools.selected = id
			}
		}
	} else {
		tools.expanded[id] = true
	}
	tools.version++
}

pub fn (mut tools DevTools) expand_all(id i64) {
	node := tools.node(id) or { return }
	tools.expand_subtree(node, 0)
	tools.version++
}

fn (mut tools DevTools) expand_subtree(node &dom.Node, count int) int {
	mut expanded := count
	for child in visible_children(node) {
		if expanded >= max_rows {
			break
		}
		if child.is_element() || child.is_shadow_root() {
			tools.expanded[node_id(child)] = true
			expanded = tools.expand_subtree(child, expanded + 1)
		}
	}
	tools.expanded[node_id(node)] = true
	return expanded
}

pub fn (mut tools DevTools) collapse_all(id i64) {
	node := tools.node(id) or { return }
	tools.collapse_subtree(node)
	if selected := tools.selected_node() {
		if contains(node, selected) {
			tools.selected = id
		}
	}
	tools.version++
}

fn (mut tools DevTools) collapse_subtree(node &dom.Node) {
	tools.expanded.delete(node_id(node))
	for child in visible_children(node) {
		tools.collapse_subtree(child)
	}
}

// contains reports whether `node` is a shadow-including inclusive ancestor of `other`.
pub fn contains(node &dom.Node, other &dom.Node) bool {
	mut current := ?&dom.Node(other)
	for {
		candidate := current or { return false }
		if voidptr(candidate) == voidptr(node) {
			return true
		}
		current = tree_parent(candidate)
	}
	return false
}

// reveal_node expands every ancestor of `node` and selects it. It reports
// whether the expansion changed.
pub fn (mut tools DevTools) reveal_node(node &dom.Node) bool {
	mut changed := false
	mut current := tree_parent(node)
	for {
		parent := current or { break }
		if !parent.is_document() {
			id := node_id(parent)
			if !(tools.expanded[id] or { false }) {
				tools.expanded[id] = true
				changed = true
			}
		}
		current = tree_parent(parent)
	}
	tools.selected = node_id(node)
	tools.reveal = true
	tools.version++
	return changed
}

// click records a row click and reports whether it completed a double click.
pub fn (mut tools DevTools) click(id i64, now i64) bool {
	double := tools.click_node == id && now - tools.click_at <= double_click_ns
	tools.click_node = if double { i64(0) } else { id }
	tools.click_at = now
	return double
}

// key moves the selection for a tree navigation key.
pub fn (mut tools DevTools) key(name string) bool {
	index := tools.row_index(tools.selected)
	if index < 0 {
		for row in tools.rows {
			if row.selectable() {
				tools.select(row.node)
				return true
			}
		}
		return false
	}
	row := tools.rows[index]
	match name {
		'up' {
			for i := index - 1; i >= 0; i-- {
				if tools.rows[i].selectable() {
					tools.select(tools.rows[i].node)
					break
				}
			}
		}
		'down' {
			for i := index + 1; i < tools.rows.len; i++ {
				if tools.rows[i].selectable() {
					tools.select(tools.rows[i].node)
					break
				}
			}
		}
		'right' {
			if row.expandable && !row.expanded {
				tools.toggle(row.node)
			} else if row.expanded && index + 1 < tools.rows.len
				&& tools.rows[index + 1].selectable() {
				tools.select(tools.rows[index + 1].node)
			}
		}
		'left' {
			if row.expanded {
				tools.toggle(row.node)
			} else if node := tools.node(row.node) {
				if parent := tree_parent(node) {
					if tools.row_index(node_id(parent)) >= 0 {
						tools.select(node_id(parent))
					}
				}
			}
		}
		'home', 'end' {
			rows := tools.rows.filter(it.selectable())
			if rows.len > 0 {
				tools.select(if name == 'home' { rows[0].node } else { rows.last().node })
			}
		}
		else {
			return false
		}
	}
	tools.reveal = true
	return true
}

// selection_after_removal picks the next sibling row, then the previous
// sibling, then the parent, for the node about to be removed.
pub fn (tools &DevTools) selection_after_removal(id i64) i64 {
	index := tools.row_index(id)
	if index < 0 {
		return 0
	}
	depth := tools.rows[index].depth
	for i := index + 1; i < tools.rows.len; i++ {
		row := tools.rows[i]
		if row.depth < depth {
			break
		}
		if row.depth == depth && row.selectable() && row.node != id {
			return row.node
		}
	}
	for i := index - 1; i >= 0; i-- {
		row := tools.rows[i]
		if row.depth < depth {
			break
		}
		if row.depth == depth && row.selectable() {
			return row.node
		}
	}
	node := tools.node(id) or { return 0 }
	parent := tree_parent(node) or { return 0 }
	return if parent.is_document() { i64(0) } else { node_id(parent) }
}

// pane_height clamps the requested height to the space between the toolbar
// and the status bar, keeping part of the document visible.
pub fn pane_height(height f64, available f64) f64 {
	maximum := math.max(min_height, available - min_document_height)
	return math.min(math.max(height, min_height), maximum)
}

pub fn (tools &DevTools) editor_text_height() f64 {
	editor := tools.editor or { return 0 }
	lines := editor.text.count('\n') + 1
	return math.min(math.max(f64(lines) * 15 + 10, 64.0), 240.0)
}

pub fn (tools &DevTools) row_extent(row Row) f64 {
	return if row.kind == .editor { tools.editor_text_height() + 34 } else { row_height }
}

pub fn (tools &DevTools) row_top(index int) f64 {
	mut top := tree_padding
	for i in 0 .. math.min(index, tools.rows.len) {
		top += tools.row_extent(tools.rows[i])
	}
	return top
}

// row_at maps a y coordinate in the tree's scrolled content to a row index.
pub fn (tools &DevTools) row_at(y f64) int {
	mut top := tree_padding
	for index, row in tools.rows {
		extent := tools.row_extent(row)
		if y >= top && y < top + extent {
			return index
		}
		top += extent
	}
	return -1
}

// breadcrumbs lists the selected node's element ancestors, outermost first.
pub fn (tools &DevTools) breadcrumbs() []&dom.Node {
	mut chain := []&dom.Node{}
	mut current := tools.selected_node()
	for {
		node := current or { break }
		if node.is_document() {
			break
		}
		if node.is_element() || node.is_shadow_root() {
			chain << node
		}
		current = tree_parent(node)
	}
	return chain.reverse()
}
