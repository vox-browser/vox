// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from:
// - Libraries/LibWeb/DOM/NodeList.cpp
// - Libraries/LibWeb/DOM/LiveNodeList.cpp
// - Libraries/LibWeb/DOM/StaticNodeList.cpp
// - Libraries/LibWeb/DOM/HTMLCollection.cpp
// - Libraries/LibWeb/DOM/NamedNodeMap.cpp
// - Libraries/LibWeb/DOM/DOMTokenList.cpp
// - Libraries/LibWeb/DOM/NodeFilter.cpp
// - Libraries/LibWeb/DOM/NodeIterator.cpp
// - Libraries/LibWeb/DOM/TreeWalker.cpp
// - Libraries/LibWeb/DOM/NodeOperations.cpp
// - Libraries/LibWeb/DOM/ParentNode.cpp
// - Libraries/LibWeb/DOM/AbstractRange.cpp
// - Libraries/LibWeb/DOM/StaticRange.cpp
// - Libraries/LibWeb/DOM/Range.cpp
// - Libraries/LibWeb/DOM/Position.cpp
module dom

import platform

__global dom_live_ranges map[u64]&Range

// The current V DOM port has skeletal storage for some platform objects.
// This file keeps the translated behavior narrow and uses simple snapshots
// where the original C++ object has cache/filter/GC state that is not present
// in the existing V structs yet.
pub enum CollectionScope {
	children
	descendants
}

pub enum LiveNodeListScope {
	children
	descendants
}

pub enum HTMLCollectionScope {
	children
	descendants
}

pub enum NodeFilterResult {
	filter_accept = 1
	filter_reject = 2
	filter_skip   = 3
}

pub enum NodeFilterWhatToShow {
	show_all                    = 0xffffffff
	show_element                = 0x1
	show_attribute              = 0x2
	show_text                   = 0x4
	show_cdata_section          = 0x8
	show_processing_instruction = 0x40
	show_comment                = 0x80
	show_document               = 0x100
	show_document_type          = 0x200
	show_document_fragment      = 0x400
}

pub enum NodeIteratorDirection {
	next
	previous
}

pub enum TreeWalkerChildTraversalType {
	first
	last
}

pub enum TreeWalkerSiblingTraversalType {
	next
	previous
}

pub enum ReturnMatches {
	first
	all
}

pub enum RelativeBoundaryPointPosition {
	equal
	before
	after
}

pub enum RangeStartOrEnd {
	start
	end
}

pub enum HowToCompareBoundaryPoints {
	start_to_start = 0
	start_to_end   = 1
	end_to_end     = 2
	end_to_start   = 3
}

pub struct BoundaryPoint {
pub mut:
	node   &Node = unsafe { nil }
	offset int
}

pub struct NodePointer {
pub mut:
	node           &Node = unsafe { nil }
	is_before_node bool = true
}

pub struct NodeOrString {
pub mut:
	node    ?&Node
	text    string
	is_text bool
}

pub fn node_or_string_from_node(node &Node) NodeOrString {
	return NodeOrString{
		node: node
	}
}

pub fn node_or_string_from_string(text string) NodeOrString {
	return NodeOrString{
		text: text
		is_text: true
	}
}

fn always_accept_node(node &Node) bool {
	_ = node
	return true
}

fn always_accept_element(element &Element) bool {
	_ = element
	return true
}

fn never_sort_elements(a &Element, b &Element) bool {
	_ = a
	_ = b
	return false
}

fn is_ascii_whitespace(ch u8) bool {
	return ch == ` ` || ch == `\t` || ch == `\n` || ch == `\r` || ch == `\f`
}

fn split_on_ascii_whitespace(input string) []string {
	mut result := []string{}
	mut start := -1
	for i := 0; i < input.len; i++ {
		if is_ascii_whitespace(input[i]) {
			if start >= 0 {
				result << input[start..i]
				start = -1
			}
		} else if start < 0 {
			start = i
		}
	}
	if start >= 0 {
		result << input[start..]
	}
	return result
}

fn append_to_ordered_set(mut set []string, item string) {
	if item !in set {
		set << item
	}
}

fn remove_from_ordered_set(mut set []string, item string) {
	index := set.index(item)
	if index >= 0 {
		set.delete(index)
	}
}

fn replace_in_ordered_set(mut set []string, item string, replacement string) {
	item_index := set.index(item)
	if item_index < 0 {
		return
	}
	replacement_index := set.index(replacement)
	if replacement_index < 0 {
		set[item_index] = replacement
		return
	}
	if item_index == replacement_index {
		return
	}
	index_to_set := if item_index < replacement_index { item_index } else { replacement_index }
	index_to_remove := if item_index > replacement_index { item_index } else { replacement_index }
	set[index_to_set] = replacement
	set.delete(index_to_remove)
}

fn node_matches_name_filter(node &Node, name string) bool {
	if name.len == 0 {
		return true
	}
	element := node.as_element() or { return false }
	if attr := element.get_attribute('name') {
		return attr == name
	}
	if element_name := element.get_name() {
		return element_name == name
	}
	return false
}

fn collect_nodes_for_scope(root &Node, scope CollectionScope, filter fn(&Node) bool) []&Node {
	mut nodes := []&Node{}
	nodes_ptr := &nodes
	node_filter := fn [nodes_ptr, filter] (node &Node) TraversalDecision {
		if filter(node) {
			dom_ptr_push(nodes_ptr, node)
		}
		return .@continue
	}
	if scope == .descendants {
		root.for_each_in_subtree(node_filter)
	} else {
		root.for_each_child(node_filter)
	}
	return nodes
}

fn collect_elements_for_scope(root &Node, scope CollectionScope, filter fn(&Element) bool) []&Element {
	mut elements := []&Element{}
	elements_ptr := &elements
	node_filter := fn [elements_ptr, filter] (node &Node) TraversalDecision {
		if element := node.as_element() {
			if filter(element) {
				dom_ptr_push(elements_ptr, element)
			}
		}
		return .@continue
	}
	if scope == .descendants {
		root.for_each_in_subtree(node_filter)
	} else {
		root.for_each_child(node_filter)
	}
	return elements
}

// --- Node helpers needed by collection/range traversal ---
pub fn (n &Node) node_type() u16 {
	return n.node_type_value()
}

pub fn (n &Node) child_at_index(index int) ?&Node {
	if index < 0 || index >= n.children.len {
		return none
	}
	return n.children[index]
}

pub fn (n &Node) is_parent_of(child &Node) bool {
	parent := child.parent() or { return false }
	return parent == n
}

pub fn (n &Node) next_in_pre_order(root ?&Node) ?&Node {
	if first := n.first_child() {
		return first
	}
	mut current := unsafe { &Node(n) }
	for {
		if root_node := root {
			// Identity, without copying both nodes through Node's == operator.
			if voidptr(current) == voidptr(root_node) {
				return none
			}
		}
		if sibling := current.next_sibling() {
			return sibling
		}
		parent := current.parent() or { return none }
		current = unsafe { &Node(parent) }
	}
	return none
}

pub fn (n &Node) previous_in_pre_order() ?&Node {
	if previous := n.previous_sibling() {
		mut candidate := unsafe { &Node(previous) }
		for {
			last := candidate.last_child() or { break }
			candidate = unsafe { &Node(last) }
		}
		return candidate
	}
	return n.parent()
}

pub fn (n &Node) is_following(other &Node) bool {
	return (n.compare_document_position(other) & document_position_preceding) != 0
}

pub fn (n &Node) is_preceding(other &Node) bool {
	return (n.compare_document_position(other) & document_position_following) != 0
}

pub fn (mut t Text) substring_data(offset int, count int) !string {
	return t.CharacterData.substring_data(offset, count)
}

// --- NodeList / LiveNodeList / StaticNodeList ---
@[heap]
pub struct LiveNodeList {
	NodeList
}

@[heap]
pub struct StaticNodeList {
	NodeList
}

pub fn NodeList.new() &NodeList {
	return &NodeList{}
}

pub fn (mut nl NodeList) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(NodeList)
}

fn collection_scope_from_live_node_list_scope(scope LiveNodeListScope) CollectionScope {
	return if scope == .descendants { .descendants } else { .children }
}

pub fn (nl &NodeList) collection() []&Node {
	if nl.is_live && nl.node_root != unsafe { nil } {
		return collect_nodes_for_scope(nl.node_root, collection_scope_from_live_node_list_scope(nl.live_scope), nl.live_filter)
	}
	if nl.nodes.len > 0 {
		return nl.nodes.clone()
	}
	if nl.node_root != unsafe { nil } {
		if nl.name_filter.len == 0 {
			return nl.node_root.children.clone()
		}
		return collect_nodes_for_scope(nl.node_root, .descendants, fn [nl] (node &Node) bool {
			return node_matches_name_filter(node, nl.name_filter)
		})
	}
	if nl.root != unsafe { nil } {
		root_node := unsafe { &Node(nl.root) }
		return collect_nodes_for_scope(root_node, .descendants, fn [nl] (node &Node) bool {
			return node_matches_name_filter(node, nl.name_filter)
		})
	}
	return []
}

// https://dom.spec.whatwg.org/#dom-nodelist-length
pub fn (nl &NodeList) length() int {
	return nl.collection().len
}

// https://dom.spec.whatwg.org/#dom-nodelist-item
pub fn (nl &NodeList) item(index int) ?&Node {
	// The item(index) method must return the indexth node in the collection. If there is no indexth node in the collection, then the method must return null.
	nodes := nl.collection()
	if index < 0 || index >= nodes.len {
		return none
	}
	return nodes[index]
}

pub fn (nl &NodeList) item_value(index int) ?&Node {
	return nl.item(index)
}

pub fn LiveNodeList.create(root &Node, scope LiveNodeListScope, filter fn(&Node) bool) &NodeList {
	return &NodeList{
		node_root: root
		is_live: true
		live_scope: scope
		live_filter: filter
	}
}

pub fn (mut l LiveNodeList) visit_edges(mut visitor CellVisitor) {
	if l.node_root != unsafe { nil } {
		visitor.visit(l.node_root)
	}
}

pub fn (l &LiveNodeList) collection() []&Node {
	return l.NodeList.collection()
}

pub fn (l &LiveNodeList) first_matching(filter fn(&Node) bool) ?&Node {
	for node in l.collection() {
		if filter(node) {
			return node
		}
	}
	return none
}

// https://dom.spec.whatwg.org/#dom-nodelist-length
pub fn (l &LiveNodeList) length() int {
	return l.collection().len
}

// https://dom.spec.whatwg.org/#dom-nodelist-item
pub fn (l &LiveNodeList) item(index int) ?&Node {
	nodes := l.collection()
	if index < 0 || index >= nodes.len {
		return none
	}
	return nodes[index]
}

pub fn StaticNodeList.create(static_nodes []&Node) &NodeList {
	return &NodeList{
		nodes: static_nodes.clone()
	}
}

pub fn (mut s StaticNodeList) visit_edges(mut visitor CellVisitor) {
	for node in s.nodes {
		visitor.visit(node)
	}
}

// https://dom.spec.whatwg.org/#dom-nodelist-length
pub fn (s &StaticNodeList) length() int {
	return s.nodes.len
}

// https://dom.spec.whatwg.org/#dom-nodelist-item
pub fn (s &StaticNodeList) item(index int) ?&Node {
	if index < 0 || index >= s.nodes.len {
		return none
	}
	return s.nodes[index]
}

// --- HTMLCollection ---
pub fn HTMLCollection.create(root &ParentNode, scope HTMLCollectionScope, filter fn(&Element) bool, sort fn(&Element, &Element) bool) &HTMLCollection {
	mut collection := &HTMLCollection{
		root: root
		scope: scope
		filter: filter
		sort: sort
	}
	collection.update_cache_if_needed()
	return collection
}

fn sort_elements_with_comparator(mut elements []&Element, sort fn(&Element, &Element) bool) {
	for i := 1; i < elements.len; i++ {
		mut j := i
		for j > 0 && sort(elements[j], elements[j - 1]) {
			tmp := elements[j - 1]
			elements[j - 1] = elements[j]
			elements[j] = tmp
			j--
		}
	}
}

fn html_collection_id_for_element(element &Element) ?string {
	if id := element.id() {
		if id.len > 0 {
			return id
		}
	}
	return none
}

fn html_collection_html_name_for_element(element &Element) ?string {
	if element.namespace_uri() or { '' } == namespace_html_uri {
		if name := element.get_attribute('name') {
			if name.len > 0 {
				return name
			}
		}
	}
	return none
}

fn (c &HTMLCollection) element_for_supported_name(name string) ?&Element {
	for element in c.cached_elements {
		if id := html_collection_id_for_element(element) {
			if id == name {
				return element
			}
		}
		if element_name := html_collection_html_name_for_element(element) {
			if element_name == name {
				return element
			}
		}
	}
	return none
}

fn (c &HTMLCollection) ordered_supported_names() []string {
	mut result := []string{}
	for element in c.cached_elements {
		// 1. If element has an ID which is not in result, append element's ID to result.
		if id := html_collection_id_for_element(element) {
			append_to_ordered_set(mut result, id)
		}
		// 2. If element is in the HTML namespace and has a name attribute whose value
		//    is neither the empty string nor is in result, append element's name attribute value to result.
		if name := html_collection_html_name_for_element(element) {
			append_to_ordered_set(mut result, name)
		}
	}
	return result
}

pub fn HTMLCollection.empty() &HTMLCollection {
	return &HTMLCollection{}
}

pub fn (mut c HTMLCollection) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(HTMLCollection)
}

pub fn (mut c HTMLCollection) visit_edges(mut visitor CellVisitor) {
	if c.root != unsafe { nil } {
		visitor.visit(c.root)
	}
	for element in c.cached_elements {
		visitor.visit(element)
	}
}

pub fn (c &HTMLCollection) update_name_to_element_mappings_if_needed() {
	// The C++ object caches supported named properties. The current V
	// translation derives them from the current collected elements on demand.
	c.update_cache_if_needed()
}

pub fn (c &HTMLCollection) update_cache_if_needed() {
	if c.root == unsafe { nil } {
		return
	}

	root_node := c.root.as_node()
	document := root_node.document()
	current_dom_tree_version := if document == unsafe { nil } {
		u64(0)
	} else {
		document.dom_tree_version()
	}
	if c.cache_initialized && c.cached_dom_tree_version == current_dom_tree_version {
		return
	}

	collection_scope := if c.scope == .descendants {
		CollectionScope.descendants
	} else {
		CollectionScope.children
	}
	mut elements := collect_elements_for_scope(root_node, collection_scope, c.filter)
	sort_elements_with_comparator(mut elements, c.sort)

	mut mutable_collection := unsafe { &HTMLCollection(c) }
	mutable_collection.cached_elements = elements
	mutable_collection.cached_dom_tree_version = current_dom_tree_version
	mutable_collection.cache_generation++
	mutable_collection.cache_initialized = true
}

pub fn (c &HTMLCollection) cache_generation_for_testing() u64 {
	return c.cache_generation
}

pub fn (c &HTMLCollection) collect_matching_elements() []&Element {
	c.update_cache_if_needed()
	return c.cached_elements.clone()
}

// https://dom.spec.whatwg.org/#dom-htmlcollection-length
pub fn (c &HTMLCollection) length() int {
	// The length getter steps are to return the number of nodes represented by the collection.
	c.update_cache_if_needed()
	return c.cached_elements.len
}

// https://dom.spec.whatwg.org/#dom-htmlcollection-item
pub fn (c &HTMLCollection) item(index int) ?&Element {
	// The item(index) method steps are to return the indexth element in the collection. If there is no indexth element in the collection, then the method must return null.
	c.update_cache_if_needed()
	if index < 0 || index >= c.cached_elements.len {
		return none
	}
	return c.cached_elements[index]
}

// https://dom.spec.whatwg.org/#dom-htmlcollection-nameditem-key
pub fn (c &HTMLCollection) named_item(key string) ?&Element {
	// 1. If key is the empty string, return null.
	if key.len == 0 {
		return none
	}
	c.update_name_to_element_mappings_if_needed()
	return c.element_for_supported_name(key)
}

// https://dom.spec.whatwg.org/#ref-for-dfn-supported-property-names
pub fn (c &HTMLCollection) is_supported_property_name(name string) bool {
	c.update_name_to_element_mappings_if_needed()
	return c.element_for_supported_name(name) != none
}

// https://dom.spec.whatwg.org/#ref-for-dfn-supported-property-names
pub fn (c &HTMLCollection) supported_property_names() []string {
	// 1. Let result be an empty list.
	// 2. For each element represented by the collection, in tree order.
	// 3. Return result.
	c.update_name_to_element_mappings_if_needed()
	return c.ordered_supported_names()
}

pub fn (c &HTMLCollection) item_value(index int) ?&Element {
	return c.item(index)
}

pub fn (c &HTMLCollection) named_item_value(name string) ?&Element {
	return c.named_item(name)
}

// --- HTMLAllCollection ---
pub fn (collection &HTMLAllCollection) is_htmldda() bool {
	_ = collection
	return true
}

pub fn HTMLAllCollection.create(root &ParentNode, scope HTMLAllCollectionScope, filter fn(&Element) bool) &HTMLAllCollection {
	return &HTMLAllCollection{
		root: root
		scope: scope
		filter: filter
	}
}

fn is_all_named_element(element &Element) bool {
	return element.namespace_uri() or { '' } == namespace_html_uri && element.local_name() in [
		'a',
		'button',
		'embed',
		'form',
		'frame',
		'frameset',
		'iframe',
		'img',
		'input',
		'map',
		'meta',
		'object',
		'select',
		'textarea',
	]
}

pub fn (collection &HTMLAllCollection) collect_matching_elements() []&Element {
	if collection.root == unsafe { nil } {
		return []
	}
	scope := if collection.scope == .descendants {
		CollectionScope.descendants
	} else {
		CollectionScope.children
	}
	return collect_elements_for_scope(collection.root.as_node(), scope, collection.filter)
}

pub fn (collection &HTMLAllCollection) length() int {
	return collection.collect_matching_elements().len
}

pub fn (collection &HTMLAllCollection) indexed_item(index int) ?&Element {
	elements := collection.collect_matching_elements()
	if index < 0 || index >= elements.len {
		return none
	}
	return elements[index]
}

pub fn (collection &HTMLAllCollection) named_item(name string) ?HTMLAllCollectionResult {
	if name == '' || collection.root == unsafe { nil } {
		return none
	}
	matching := HTMLCollection.create(collection.root, .descendants, fn [name] (element &Element) bool {
		if id := element.id() {
			if id == name {
				return true
			}
		}
		return is_all_named_element(element) && element.get_attribute_value('name') == name
	}, never_sort_elements)
	if matching.length() == 0 {
		return none
	}
	if matching.length() == 1 {
		return HTMLAllCollectionResult{
			element: matching.item(0) or { return none }
		}
	}
	return HTMLAllCollectionResult{
		collection: matching
	}
}

pub fn (collection &HTMLAllCollection) get_the_all_named_elements(name string) ?HTMLAllCollectionResult {
	return collection.named_item(name)
}

pub fn (collection &HTMLAllCollection) get_the_all_indexed_element(index u32) ?&Element {
	if index > u32(0x7fff_ffff) {
		return none
	}
	return collection.indexed_item(int(index))
}

pub fn (collection &HTMLAllCollection) get_the_all_indexed_or_named_elements(name_or_index string) ?HTMLAllCollectionResult {
	return collection.item(name_or_index)
}

pub fn (collection &HTMLAllCollection) item_value(index uint) ?&Element {
	if index > uint(0x7fff_ffff) {
		return none
	}
	return collection.get_the_all_indexed_element(u32(index))
}

pub fn (collection &HTMLAllCollection) named_item_value(name string) ?HTMLAllCollectionResult {
	return collection.named_item(name)
}

pub fn (collection &HTMLAllCollection) item(name_or_index ?string) ?HTMLAllCollectionResult {
	value := name_or_index or { return none }
	if value != '' && value.bytes().all(it >= `0` && it <= `9`) {
		index := value.int()
		if element := collection.indexed_item(index) {
			return HTMLAllCollectionResult{
				element: element
			}
		}
		return none
	}
	return collection.named_item(value)
}

pub fn (collection &HTMLAllCollection) supported_property_names() []string {
	mut result := []string{}
	for element in collection.collect_matching_elements() {
		if id := element.id() {
			if id != '' {
				append_to_ordered_set(mut result, id)
			}
		}
		if is_all_named_element(element) {
			if name := element.get_attribute('name') {
				if name != '' {
					append_to_ordered_set(mut result, name)
				}
			}
		}
	}
	return result
}

// --- NamedNodeMap ---
pub fn NamedNodeMap.create(mut element Element) &NamedNodeMap {
	return element.attributes()
}

pub fn (mut n NamedNodeMap) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(NamedNodeMap)
}

pub fn (mut n NamedNodeMap) visit_edges(mut visitor CellVisitor) {
	for attr in n.attrs {
		visitor.visit(attr)
	}
	if n.element != unsafe { nil } {
		visitor.visit(n.element)
	}
}

// https://dom.spec.whatwg.org/#ref-for-dfn-supported-property-names
pub fn (n &NamedNodeMap) supported_property_names() []string {
	// 1. Let names be the qualified names of the attributes in this NamedNodeMap object's attribute list, with duplicates omitted, in order.
	mut names := []string{cap: n.attrs.len}
	for attribute in n.attrs {
		attribute_name := attribute.name()
		if attribute_name !in names {
			names << attribute_name
		}
	}
	// 2. If this NamedNodeMap object's element is in the HTML namespace and its node document is an HTML document, then for each name of names:
	if n.element != unsafe { nil } && n.element.namespace_uri() or { '' } == namespace_html_uri && n.element.document().document_type() == .html {
		names = names.filter(it == to_ascii_lowercase(it))
	}
	// 3. Return names.
	return names
}

// https://dom.spec.whatwg.org/#dom-namednodemap-getnameditem
pub fn (n &NamedNodeMap) get_named_item(qualified_name string) ?&Attr_ {
	return n.get_attribute(qualified_name)
}

// https://dom.spec.whatwg.org/#dom-namednodemap-getnameditemns
pub fn (n &NamedNodeMap) get_named_item_ns(namespace_ ?string, local_name string) ?&Attr_ {
	return n.get_attribute_ns(namespace_, local_name)
}

// https://dom.spec.whatwg.org/#dom-namednodemap-setnameditem
pub fn (mut n NamedNodeMap) set_named_item(attribute &Attr_) !&Attr_ {
	return n.set_attribute(attribute)
}

// https://dom.spec.whatwg.org/#dom-namednodemap-setnameditemns
pub fn (mut n NamedNodeMap) set_named_item_ns(attribute &Attr_) !&Attr_ {
	return n.set_attribute(attribute)
}

// https://dom.spec.whatwg.org/#dom-namednodemap-removenameditem
pub fn (mut n NamedNodeMap) remove_named_item(qualified_name string) !&Attr_ {
	// 1. Let attr be the result of removing an attribute given qualifiedName and element.
	attribute := n.take_attribute(qualified_name) or {
		// 2. If attr is null, then throw a "NotFoundError" DOMException.
		return error("NotFoundError: Attribute with name '${qualified_name}' not found")
	}
	// 3. Return attr.
	return attribute
}

// https://dom.spec.whatwg.org/#dom-namednodemap-removenameditemns
pub fn (mut n NamedNodeMap) remove_named_item_ns(namespace_ ?string, local_name string) !&Attr_ {
	// 1. Let attr be the result of removing an attribute given namespace, localName, and element.
	attribute := n.take_attribute_ns(namespace_, local_name) or {
		// 2. If attr is null, then throw a "NotFoundError" DOMException.
		return error("NotFoundError: Attribute with namespace and local name '${local_name}' not found")
	}
	// 3. Return attr.
	return attribute
}

// https://dom.spec.whatwg.org/#concept-element-attributes-set
pub fn (mut n NamedNodeMap) set_attribute(attribute &Attr_) !&Attr_ {
	// 1. Obtain the Trusted Types-compliant value for this attribute mutation.
	if n.element != unsafe { nil } {
		verified_value := n.element.document().trusted_types_compliant_attribute_value(n.element, attribute.local_name_, attribute.namespace_uri_, attribute.value_)!
		mut mutable_attribute := unsafe { &Attr_(attribute) }
		mutable_attribute.value_ = verified_value
	}
	// 2. If attr's element is neither null nor element, throw an "InUseAttributeError" DOMException.
	if owner := attribute.owner_element() {
		if n.element != unsafe { nil } && owner != n.element {
			return error('InUseAttributeError: Attribute must not already be in use')
		}
	}
	// 3. Let oldAttr be the result of getting an attribute given attr's namespace, attr's local name, and element.
	for index, old_attribute in n.attrs {
		if option_string_equal(old_attribute.namespace_uri_, attribute.namespace_uri_) && old_attribute.local_name_ == attribute.local_name_ {
			// 4. If oldAttr is attr, return attr.
			if old_attribute == attribute {
				return attribute
			}
			// 6. If oldAttr is non-null, then replace oldAttr with attr.
			n.replace_attribute(old_attribute, attribute, index)
			// 8. Return oldAttr.
			return old_attribute
		}
	}
	// 7. Otherwise, append attr to element.
	n.append_attribute(attribute)
	return attribute
}

// https://dom.spec.whatwg.org/#concept-element-attributes-replace
pub fn (mut n NamedNodeMap) replace_attribute(old_attribute &Attr_, new_attribute &Attr_, old_attribute_index int) {
	if old_attribute_index < 0 || old_attribute_index >= n.attrs.len {
		return
	}
	n.attrs[old_attribute_index] = new_attribute
	mut mutable_new_attribute := unsafe { &Attr_(new_attribute) }
	mutable_new_attribute.owner_element_ = n.element
	mut mutable_old_attribute := unsafe { &Attr_(old_attribute) }
	mutable_old_attribute.owner_element_ = none
	if n.element != unsafe { nil } {
		old_attribute.handle_attribute_changes(n.element, old_attribute.value_, new_attribute.value_)
	}
}

// https://dom.spec.whatwg.org/#concept-element-attributes-remove
pub fn (mut n NamedNodeMap) remove_attribute_at_index(attribute_index int) ?&Attr_ {
	if attribute_index < 0 || attribute_index >= n.attrs.len {
		return none
	}
	attribute := n.attrs[attribute_index]
	n.attrs.delete(attribute_index)
	mut mutable_attribute := unsafe { &Attr_(attribute) }
	old_value := attribute.value_
	element := attribute.owner_element()
	mutable_attribute.owner_element_ = none
	if owner := element {
		attribute.handle_attribute_changes(owner, old_value, none)
	}
	return attribute
}

// https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-name
pub fn (mut n NamedNodeMap) take_attribute(qualified_name string) ?&Attr_ {
	index := n.attribute_index_by_name(qualified_name) or { return none }
	return n.remove_attribute_at_index(index)
}

// https://dom.spec.whatwg.org/#concept-element-attributes-remove-by-namespace
pub fn (mut n NamedNodeMap) take_attribute_ns(namespace_ ?string, local_name string) ?&Attr_ {
	index := n.attribute_index_by_namespace(namespace_, local_name) or { return none }
	return n.remove_attribute_at_index(index)
}

pub fn (n &NamedNodeMap) item_value(index int) ?&Attr_ {
	return n.item(index)
}

pub fn (n &NamedNodeMap) named_item_value(name string) ?&Attr_ {
	return n.get_named_item(name)
}

// https://dom.spec.whatwg.org/#dom-element-removeattributenode
pub fn (mut n NamedNodeMap) remove_attribute_node_checked(attr &Attr_) !&Attr_ {
	// 1. If this's attribute list does not contain attr, then throw a "NotFoundError" DOMException.
	for index, attribute in n.attrs {
		if attribute == attr {
			// 2. Remove attr.
			n.remove_attribute_at_index(index)
			// 3. Return attr.
			return attr
		}
	}
	return error('NotFoundError: Attribute not found')
}

// --- DOMTokenList ---
@[heap]
pub struct DOMTokenList {
pub mut:
	associated_element   &Element = unsafe { nil }
	associated_attribute string
	token_set            []string
}

pub fn DOMTokenList.create(associated_element &Element, associated_attribute string) &DOMTokenList {
	mut list := &DOMTokenList{
		associated_element: associated_element
		associated_attribute: associated_attribute
	}
	// When a DOMTokenList object set is created:
	// 1. Let element be set's element.
	// 2. Let attributeName be set's attribute name.
	// 3. Let value be the result of getting an attribute value given element and attributeName.
	value := associated_element.get_attribute_value(associated_attribute)
	// 4. Run the attribute change steps for element, attributeName, value, value, and null.
	list.associated_attribute_changed(value)
	return list
}

pub fn (mut d DOMTokenList) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(DOMTokenList)
}

pub fn (mut d DOMTokenList) visit_edges(mut visitor CellVisitor) {
	if d.associated_element != unsafe { nil } {
		visitor.visit(d.associated_element)
	}
}

// https://dom.spec.whatwg.org/#ref-for-domtokenlist
pub fn (mut d DOMTokenList) associated_attribute_changed(value string) {
	// 1. If localName is set's attribute name, namespace is null, and value is null, then empty token set.
	// 2. Otherwise, if localName is set's attribute name and namespace is null, then set set's token set to value, parsed.
	// AD-HOC: The caller is responsible for checking the name and namespace.
	d.token_set.clear()
	if value.len == 0 {
		return
	}
	d.token_set = d.parse_ordered_set(value)
}

pub fn (d &DOMTokenList) length() int {
	return d.token_set.len
}

// https://dom.spec.whatwg.org/#dom-domtokenlist-item
pub fn (d &DOMTokenList) item(index int) ?string {
	// 1. If index is equal to or greater than this's token set's size, then return null.
	if index < 0 || index >= d.token_set.len {
		return none
	}
	// 2. Return this's token set[index].
	return d.token_set[index]
}

// https://dom.spec.whatwg.org/#dom-domtokenlist-contains
pub fn (d &DOMTokenList) contains(token string) bool {
	return token in d.token_set
}

// https://dom.spec.whatwg.org/#dom-domtokenlist-add
pub fn (mut d DOMTokenList) add(tokens []string) ! {
	// 1. For each token of tokens:
	for token in tokens {
		// a. If token is the empty string, then throw a "SyntaxError" DOMException.
		// b. If token contains any ASCII whitespace, then throw an "InvalidCharacterError" DOMException.
		d.validate_token(token)!
		// 2. For each token of tokens, append token to this's token set.
		append_to_ordered_set(mut d.token_set, token)
	}
	// 3. Run the update steps.
	d.run_update_steps()
}

// https://dom.spec.whatwg.org/#dom-domtokenlist-remove
pub fn (mut d DOMTokenList) remove(tokens []string) ! {
	// 1. For each token of tokens:
	for token in tokens {
		// a. If token is the empty string, then throw a "SyntaxError" DOMException.
		// b. If token contains any ASCII whitespace, then throw an "InvalidCharacterError" DOMException.
		d.validate_token(token)!
		// 2. For each token of tokens, remove token from this's token set.
		remove_from_ordered_set(mut d.token_set, token)
	}
	// 3. Run the update steps.
	d.run_update_steps()
}

// https://dom.spec.whatwg.org/#dom-domtokenlist-toggle
pub fn (mut d DOMTokenList) toggle(token string, force ?bool) !bool {
	// 1. If token is the empty string, then throw a "SyntaxError" DOMException.
	// 2. If token contains any ASCII whitespace, then throw an "InvalidCharacterError" DOMException.
	d.validate_token(token)!
	// 3. If this's token set[token] exists, then:
	if d.contains(token) {
		// a. If force is either not given or is false, then remove token from this's token set, run the update steps and return false.
		if force == none || !force or { false } {
			remove_from_ordered_set(mut d.token_set, token)
			d.run_update_steps()
			return false
		}
		// b. Return true.
		return true
	}
	// 4. Otherwise, if force not given or is true, append token to this's token set, run the update steps, and return true.
	if force == none || force or { false } {
		append_to_ordered_set(mut d.token_set, token)
		d.run_update_steps()
		return true
	}
	// 5. Return false.
	return false
}

// https://dom.spec.whatwg.org/#dom-domtokenlist-replace
pub fn (mut d DOMTokenList) replace(token string, new_token string) !bool {
	// 1. If either token or newToken is the empty string, then throw a "SyntaxError" DOMException.
	d.validate_token_not_empty(token)!
	d.validate_token_not_empty(new_token)!
	// 2. If either token or newToken contains any ASCII whitespace, then throw an "InvalidCharacterError" DOMException.
	d.validate_token_not_whitespace(token)!
	d.validate_token_not_whitespace(new_token)!
	// 3. If this's token set does not contain token, then return false.
	if !d.contains(token) {
		return false
	}
	// 4. Replace token in this's token set with newToken.
	replace_in_ordered_set(mut d.token_set, token, new_token)
	// 5. Run the update steps.
	d.run_update_steps()
	// 6. Return true.
	return true
}

// https://dom.spec.whatwg.org/#dom-domtokenlist-supports
pub fn (mut d DOMTokenList) supports(token string) !bool {
	// 1. Let result be the return value of validation steps called with token.
	result := d.run_validation_steps(token)!
	// 2. Return result.
	return result
}

// https://dom.spec.whatwg.org/#concept-domtokenlist-validation
pub fn (d &DOMTokenList) run_validation_steps(token string) !bool {
	key := '${d.associated_element.local_name()}|${d.associated_attribute}'
	lowercase_token := to_ascii_lowercase(token)
	mut supported_tokens := []string{}
	match key {
		'link|rel' {
			supported_tokens = ['modulepreload', 'preload', 'preconnect', 'dns-prefetch', 'stylesheet',
				'icon', 'alternate', 'prefetch', 'prerender', 'next', 'manifest', 'apple-touch-icon',
				'apple-touch-icon-precomposed', 'canonical']
		}
		'a|rel', 'area|rel', 'form|rel' {
			supported_tokens = ['noreferrer', 'noopener', 'opener']
		}
		'iframe|sandbox' {
			supported_tokens = ['allow-downloads', 'allow-forms', 'allow-modals',
				'allow-orientation-lock', 'allow-pointer-lock', 'allow-popups',
				'allow-popups-to-escape-sandbox', 'allow-presentation', 'allow-same-origin',
				'allow-scripts', 'allow-top-navigation', 'allow-top-navigation-by-user-activation',
				'allow-top-navigation-to-custom-protocols']
		}
		else {
			// 1. If set's element and attribute name does not define supported tokens, then throw a TypeError.
			return error('TypeError: Attribute ${d.associated_attribute} does not define any supported tokens')
		}
	}

	// 2. Let lowercaseToken be token, in ASCII lowercase.
	// 3. If lowercaseToken is present in the supported tokens of set's element and attribute name, then return true.
	if lowercase_token in supported_tokens {
		return true
	}
	// 4. Return false.
	return false
}

// https://dom.spec.whatwg.org/#concept-ordered-set-parser
pub fn (d &DOMTokenList) parse_ordered_set(input string) []string {
	_ = d
	// 1. Let inputTokens be the result of splitting input on ASCII whitespace.
	split_values := split_on_ascii_whitespace(input)
	// 2. Let tokens be a new ordered set.
	mut tokens := []string{}
	// 3. For each token of inputTokens: append token to tokens.
	for split_value in split_values {
		append_to_ordered_set(mut tokens, split_value)
	}
	// 4. Return tokens.
	return tokens
}

// https://dom.spec.whatwg.org/#concept-ordered-set-serializer
pub fn (d &DOMTokenList) serialize_ordered_set() string {
	// The ordered set serializer takes a set and returns the concatenation of set using U+0020 SPACE.
	return d.token_set.join(' ')
}

// https://dom.spec.whatwg.org/#dom-domtokenlist-value
pub fn (d &DOMTokenList) value() string {
	if d.associated_element == unsafe { nil } {
		return ''
	}
	return d.associated_element.get_attribute_value(d.associated_attribute)
}

// https://dom.spec.whatwg.org/#ref-for-concept-element-attributes-set-value
pub fn (mut d DOMTokenList) set_value(value string) {
	if d.associated_element == unsafe { nil } {
		return
	}
	mut element := unsafe { &Element(d.associated_element) }
	element.set_attribute_value(d.associated_attribute, value)
}

pub fn (d &DOMTokenList) validate_token(token string) ! {
	d.validate_token_not_empty(token)!
	d.validate_token_not_whitespace(token)!
}

pub fn (d &DOMTokenList) validate_token_not_empty(token string) ! {
	_ = d
	if token.len == 0 {
		return error('SyntaxError: Non-empty DOM tokens are not allowed')
	}
}

pub fn (d &DOMTokenList) validate_token_not_whitespace(token string) ! {
	_ = d
	for i := 0; i < token.len; i++ {
		if is_ascii_whitespace(token[i]) {
			return error('InvalidCharacterError: DOM tokens containing ASCII whitespace are not allowed')
		}
	}
}

// https://dom.spec.whatwg.org/#concept-dtl-update
pub fn (mut d DOMTokenList) run_update_steps() {
	if d.associated_element == unsafe { nil } {
		return
	}
	// 1. If get an attribute by namespace and local name given null, set's attribute name, and set's element returns null and set's token set is empty, then return.
	if d.associated_element.get_attribute_ns(none, d.associated_attribute) == none && d.token_set.len == 0 {
		return
	}
	// 2. Set an attribute value given set's element, set's attribute name, and the result of running the ordered set serializer for set's token set.
	mut element := unsafe { &Element(d.associated_element) }
	element.set_attribute_value(d.associated_attribute, d.serialize_ordered_set())
}

pub fn (d &DOMTokenList) item_value(index int) ?string {
	return d.item(index)
}

// --- NodeFilter / NodeIterator / TreeWalker ---
pub fn NodeFilter.create(callback &CallbackType) &NodeFilter {
	return &NodeFilter{
		callback_: callback
	}
}

pub fn (mut nf NodeFilter) visit_edges(mut visitor CellVisitor) {
	visitor.visit(nf.callback_)
}

pub fn (nf &NodeFilter) callback() &CallbackType {
	return nf.callback_
}

pub fn node_filter_what_to_show_value(value NodeFilterWhatToShow) u32 {
	return u32(value)
}

pub fn node_filter_result_from_int(value int) NodeFilterResult {
	return match value {
		1 { .filter_accept }
		2 { .filter_reject }
		3 { .filter_skip }
		else { .filter_skip }
	}
}

pub fn (mut it NodeIterator) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(NodeIterator)
}

pub fn (mut it NodeIterator) finalize() {
	if it.root != unsafe { nil } {
		mut doc := unsafe { &Document(it.root.document()) }
		if doc != unsafe { nil } {
			doc.unregister_node_iterator(it)
		}
	}
}

pub fn (mut it NodeIterator) visit_edges(mut visitor CellVisitor) {
	visitor.visit(it.filter)
	visitor.visit(it.root)
	visitor.visit(it.reference_node_)
	if pointer := it.traversal_pointer {
		visitor.visit(pointer.node)
	}
}

// https://dom.spec.whatwg.org/#dom-document-createnodeiterator
pub fn NodeIterator.create(root &Node, what_to_show u32, filter ?&NodeFilter) &NodeIterator {
	// 1. Let iterator be a new NodeIterator object.
	// 2. Set iterator's root and iterator's reference to root.
	// 3. Set iterator's pointer before reference to true.
	iterator := &NodeIterator{
		root: root
		reference_node_: root
		pointer_before_reference_node_: true
		what_to_show: what_to_show
		filter: filter or { unsafe { nil } }
	}
	// 4. Set iterator's whatToShow to whatToShow.
	// 5. Set iterator's filter to filter.
	mut document := unsafe { &Document(root.document()) }
	if document != unsafe { nil } {
		document.register_node_iterator(iterator)
	}
	// 6. Return iterator.
	return iterator
}

pub fn (it &NodeIterator) root_node() &Node {
	return it.root
}

pub fn (it &NodeIterator) reference_node() &Node {
	if it.reference_node_ == unsafe { nil } {
		return it.root
	}
	return it.reference_node_
}

pub fn (it &NodeIterator) pointer_before_reference_node() bool {
	return it.pointer_before_reference_node_
}

pub fn (it &NodeIterator) what_to_show_value() u32 {
	return it.what_to_show
}

// https://dom.spec.whatwg.org/#dom-nodeiterator-detach
pub fn (mut it NodeIterator) detach() {
	_ = it
	// The detach() method steps are to do nothing.
	// Its functionality was removed, but the method itself is preserved for compatibility.
}

// https://dom.spec.whatwg.org/#concept-traversal-filter
pub fn (it &NodeIterator) filter() ?&NodeFilter {
	return it.filter_object()
}

pub fn (it &NodeIterator) filter_object() ?&NodeFilter {
	if it.filter == unsafe { nil } {
		return none
	}
	return it.filter
}

// https://dom.spec.whatwg.org/#concept-node-filter
// C++ overload: NodeIterator::filter(Node& node)
pub fn (mut it NodeIterator) filter_node(node &Node) NodeFilterResult {
	// 1. If traverser's active flag is set, then throw an "InvalidStateError" DOMException.
	if it.active {
		return .filter_reject
	}
	// 2. Let n be node's nodeType attribute value - 1.
	n := int(node.node_type()) - 1
	// 3. If the nth bit of traverser's whatToShow is not set, then return FILTER_SKIP.
	if n >= 0 && (it.what_to_show & (u32(1) << n)) == 0 {
		return .filter_skip
	}
	// 4. If traverser's filter is null, then return FILTER_ACCEPT.
	if it.filter == unsafe { nil } {
		return .filter_accept
	}
	// 5. Set traverser's active flag.
	it.active = true
	// 6. Let result be the return value of calling the filter's acceptNode operation.
	mut result := NodeFilterResult.filter_accept
	if accept_node := it.filter.callback().accept_node {
		result = node_filter_result_from_int(accept_node(node))
	}
	// 7. Unset traverser's active flag.
	it.active = false
	// 8. Return result.
	return result
}

// https://dom.spec.whatwg.org/#concept-nodeiterator-traverse
pub fn (mut it NodeIterator) traverse(direction NodeIteratorDirection) ?&Node {
	it.traversal_pointer = NodePointer{
		node: it.reference_node()
		is_before_node: it.pointer_before_reference_node_
	}
	for {
		mut pointer := it.traversal_pointer or { return none }
		if direction == .next {
			if !pointer.is_before_node {
				pointer.node = pointer.node.next_in_pre_order(it.root) or {
					it.traversal_pointer = none
					return none
				}
			} else {
				pointer.is_before_node = false
			}
		} else {
			if pointer.is_before_node {
				if pointer.node == it.root {
					it.traversal_pointer = none
					return none
				}
				pointer.node = pointer.node.previous_in_pre_order() or {
					it.traversal_pointer = none
					return none
				}
			} else {
				pointer.is_before_node = true
			}
		}
		candidate := pointer.node
		it.traversal_pointer = pointer
		result := it.filter_node(pointer.node)
		if result == .filter_accept {
			final_pointer := it.traversal_pointer or { pointer }
			it.reference_node_ = final_pointer.node
			it.pointer_before_reference_node_ = final_pointer.is_before_node
			it.traversal_pointer = none
			return candidate
		}
	}
	it.traversal_pointer = none
	return none
}

// https://dom.spec.whatwg.org/#dom-nodeiterator-nextnode
pub fn (mut it NodeIterator) next_node() ?&Node {
	return it.traverse(.next)
}

// https://dom.spec.whatwg.org/#dom-nodeiterator-previousnode
pub fn (mut it NodeIterator) previous_node() ?&Node {
	return it.traverse(.previous)
}

pub fn (mut it NodeIterator) run_pre_removing_steps_with_node_pointer(to_be_removed_node &Node, mut pointer NodePointer) {
	// NOTE: This function tries to match the behavior of other engines, but not the DOM specification.
	// Spec bug: https://github.com/whatwg/dom/issues/907
	if !to_be_removed_node.is_descendant_of(it.root) {
		return
	}
	if !to_be_removed_node.is_inclusive_ancestor_of(pointer.node) {
		return
	}
	if pointer.is_before_node {
		if next := to_be_removed_node.next_in_pre_order(it.root) {
			mut node := unsafe { &Node(next) }
			for node.is_descendant_of(to_be_removed_node) {
				node = node.next_in_pre_order(it.root) or { return }
			}
			pointer.node = node
			return
		}
		if previous := to_be_removed_node.previous_in_pre_order() {
			mut node := unsafe { &Node(previous) }
			if to_be_removed_node.is_ancestor_of(pointer.node) {
				for node.is_descendant_of(to_be_removed_node) {
					node = node.previous_in_pre_order() or { return }
				}
			}
			pointer.node = node
			pointer.is_before_node = false
		}
		return
	}
	if previous := to_be_removed_node.previous_in_pre_order() {
		mut node := unsafe { &Node(previous) }
		if to_be_removed_node.is_ancestor_of(pointer.node) {
			for node.is_descendant_of(to_be_removed_node) {
				node = node.previous_in_pre_order() or { return }
			}
		}
		pointer.node = node
		return
	}
	if next := to_be_removed_node.next_in_pre_order(it.root) {
		mut node := unsafe { &Node(next) }
		if to_be_removed_node.is_ancestor_of(pointer.node) {
			for node.is_descendant_of(to_be_removed_node) {
				node = node.previous_in_pre_order() or { return }
			}
		}
		pointer.node = node
	}
}

// https://dom.spec.whatwg.org/#nodeiterator-pre-removing-steps
pub fn (mut it NodeIterator) run_pre_removing_steps(to_be_removed_node &Node) {
	if mut traversal_pointer := it.traversal_pointer {
		it.run_pre_removing_steps_with_node_pointer(to_be_removed_node, mut traversal_pointer)
		it.traversal_pointer = traversal_pointer
	}
	mut pointer := NodePointer{
		node: it.reference_node()
		is_before_node: it.pointer_before_reference_node_
	}
	it.run_pre_removing_steps_with_node_pointer(to_be_removed_node, mut pointer)
	it.reference_node_ = pointer.node
	it.pointer_before_reference_node_ = pointer.is_before_node
}

pub fn (mut tw TreeWalker) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(TreeWalker)
}

pub fn (mut tw TreeWalker) visit_edges(mut visitor CellVisitor) {
	visitor.visit(tw.filter)
	visitor.visit(tw.root)
	visitor.visit(tw.current)
}

// https://dom.spec.whatwg.org/#dom-document-createtreewalker
pub fn TreeWalker.create(root &Node, what_to_show u32, filter ?&NodeFilter) &TreeWalker {
	// 1. Let walker be a new TreeWalker object.
	// 2. Set walker's root and walker's current to root.
	walker := &TreeWalker{
		root: root
		current: root
		what_to_show: what_to_show
		filter: filter or { unsafe { nil } }
	}
	// 3. Set walker's whatToShow to whatToShow.
	// 4. Set walker's filter to filter.
	// 5. Return walker.
	return walker
}

// https://dom.spec.whatwg.org/#dom-treewalker-currentnode
pub fn (tw &TreeWalker) current_node() &Node {
	if tw.current == unsafe { nil } {
		return tw.root
	}
	return tw.current
}

// https://dom.spec.whatwg.org/#dom-treewalker-currentnode
pub fn (mut tw TreeWalker) set_current_node(node &Node) {
	tw.current = node
}

// https://dom.spec.whatwg.org/#concept-traversal-filter
pub fn (tw &TreeWalker) filter() ?&NodeFilter {
	return tw.filter_object()
}

pub fn (tw &TreeWalker) filter_object() ?&NodeFilter {
	if tw.filter == unsafe { nil } {
		return none
	}
	return tw.filter
}

// https://dom.spec.whatwg.org/#concept-node-filter
// C++ overload: TreeWalker::filter(Node& node)
pub fn (mut tw TreeWalker) filter_node(node &Node) NodeFilterResult {
	// 1. If traverser's active flag is set, then throw an "InvalidStateError" DOMException.
	if tw.active {
		return .filter_reject
	}
	// 2. Let n be node's nodeType attribute value - 1.
	n := int(node.node_type()) - 1
	// 3. If the nth bit of traverser's whatToShow is not set, then return FILTER_SKIP.
	if n >= 0 && (tw.what_to_show & (u32(1) << n)) == 0 {
		return .filter_skip
	}
	// 4. If traverser's filter is null, then return FILTER_ACCEPT.
	if tw.filter == unsafe { nil } {
		return .filter_accept
	}
	// 5. Set traverser's active flag.
	tw.active = true
	// 6. Let result be the return value of calling the filter's acceptNode operation.
	mut result := NodeFilterResult.filter_accept
	if accept_node := tw.filter.callback().accept_node {
		result = node_filter_result_from_int(accept_node(node))
	}
	// 7. Unset traverser's active flag.
	tw.active = false
	// 8. Return result.
	return result
}

// https://dom.spec.whatwg.org/#dom-treewalker-parentnode
pub fn (mut tw TreeWalker) parent_node() ?&Node {
	mut node := tw.current_node()
	for node != tw.root {
		parent := node.parent() or { return none }
		node = unsafe { &Node(parent) }
		if tw.filter_node(node) == .filter_accept {
			tw.set_current_node(node)
			return node
		}
	}
	return none
}

// https://dom.spec.whatwg.org/#dom-treewalker-firstchild
pub fn (mut tw TreeWalker) first_child() ?&Node {
	return tw.traverse_children(.first)
}

// https://dom.spec.whatwg.org/#dom-treewalker-lastchild
pub fn (mut tw TreeWalker) last_child() ?&Node {
	return tw.traverse_children(.last)
}

// https://dom.spec.whatwg.org/#dom-treewalker-previoussibling
pub fn (mut tw TreeWalker) previous_sibling() ?&Node {
	return tw.traverse_siblings(.previous)
}

// https://dom.spec.whatwg.org/#dom-treewalker-nextsibling
pub fn (mut tw TreeWalker) next_sibling() ?&Node {
	return tw.traverse_siblings(.next)
}

// https://dom.spec.whatwg.org/#dom-treewalker-previousnode
pub fn (mut tw TreeWalker) previous_node() ?&Node {
	mut node := tw.current_node()
	for node != tw.root {
		mut sibling := node.previous_sibling()
		for sibling != none {
			node = sibling or { break }
			mut result := tw.filter_node(node)
			for result != .filter_reject && node.has_children() {
				node = node.last_child() or { break }
				result = tw.filter_node(node)
			}
			if result == .filter_accept {
				tw.set_current_node(node)
				return node
			}
			sibling = node.previous_sibling()
		}
		parent := node.parent() or { return none }
		node = unsafe { &Node(parent) }
		if tw.filter_node(node) == .filter_accept {
			tw.set_current_node(node)
			return node
		}
	}
	return none
}

// https://dom.spec.whatwg.org/#dom-treewalker-nextnode
pub fn (mut tw TreeWalker) next_node() ?&Node {
	mut node := tw.current_node()
	mut result := NodeFilterResult.filter_accept
	for {
		for result != .filter_reject && node.has_children() {
			node = node.first_child() or { break }
			result = tw.filter_node(node)
			if result == .filter_accept {
				tw.set_current_node(node)
				return node
			}
		}
		mut temporary := node
		for {
			if temporary == tw.root {
				return none
			}
			if sibling := temporary.next_sibling() {
				node = unsafe { &Node(sibling) }
				break
			}
			temporary = temporary.parent() or { return none }
		}
		result = tw.filter_node(node)
		if result == .filter_accept {
			tw.set_current_node(node)
			return node
		}
	}
	return none
}

// https://dom.spec.whatwg.org/#concept-traverse-children
pub fn (mut tw TreeWalker) traverse_children(type_ TreeWalkerChildTraversalType) ?&Node {
	mut node := if type_ == .first {
		tw.current_node().first_child()
	} else {
		tw.current_node().last_child()
	}
	for node != none {
		current := node or { break }
		result := tw.filter_node(current)
		if result == .filter_accept {
			tw.set_current_node(current)
			return current
		}
		if result == .filter_skip {
			child := if type_ == .first { current.first_child() } else { current.last_child() }
			if child != none {
				node = unsafe { &Node(child) }
				continue
			}
		}
		mut climb := unsafe { &Node(current) }
		for {
			sibling := if type_ == .first { climb.next_sibling() } else { climb.previous_sibling() }
			if sibling != none {
				node = unsafe { &Node(sibling) }
				break
			}
			parent := climb.parent() or { return none }
			if parent == tw.root || parent == tw.current_node() {
				return none
			}
			climb = unsafe { &Node(parent) }
		}
	}
	return none
}

// https://dom.spec.whatwg.org/#concept-traverse-siblings
pub fn (mut tw TreeWalker) traverse_siblings(type_ TreeWalkerSiblingTraversalType) ?&Node {
	mut node := tw.current_node()
	if node == tw.root {
		return none
	}
	for {
		mut sibling := if type_ == .next { node.next_sibling() } else { node.previous_sibling() }
		for sibling != none {
			node = sibling or { break }
			result := tw.filter_node(node)
			if result == .filter_accept {
				tw.set_current_node(node)
				return node
			}
			sibling = if type_ == .next { node.first_child() } else { node.last_child() }
			if result == .filter_reject || sibling == none {
				sibling = if type_ == .next { node.next_sibling() } else { node.previous_sibling() }
			}
		}
		parent := node.parent() or { return none }
		node = unsafe { &Node(parent) }
		if node == tw.root {
			return none
		}
		if tw.filter_node(node) == .filter_accept {
			return none
		}
	}
	return none
}

// --- NodeOperations / ParentNode ---

// https://dom.spec.whatwg.org/#convert-nodes-into-a-node
pub fn convert_nodes_to_single_node(nodes []NodeOrString, document &Document) !&Node {
	// 1. Replace each string of nodes with a new Text node whose data is the string and node document is document.
	mut converted := []&Node{}
	for node in nodes {
		if node.is_text {
			converted << new_text_node(document, node.text).as_node()
		} else if actual := node.node {
			converted << actual
		}
	}
	// 2. If nodes's size is 1, then return nodes[0].
	if converted.len == 1 {
		return converted[0]
	}
	// 3. Let fragment be a new DocumentFragment node whose node document is document.
	fragment := new_document_fragment(document)
	mut fragment_node := unsafe { &Node(fragment) }
	// 4. For each node of nodes: append node to fragment.
	for node in converted {
		fragment_node.append_child(node)!
	}
	// 5. Return fragment.
	return fragment.as_node()
}

pub fn (p &ParentNode) as_node() &Node {
	return unsafe { &Node(p) }
}

fn (mut p ParentNode) as_mut_node() &Node {
	return unsafe { &Node(&p) }
}

fn contains_named_namespace(selectors SelectorList) bool {
	return selectors.contains_named_namespace
}

fn parse_selector(document &Document, selector_text string) ?SelectorList {
	if hook := document.selector_query_hook() {
		if hook.validate == unsafe { nil } || !hook.validate(hook.target, selector_text) {
			return none
		}
		// The css side owns the parsed representation. DOM only needs an opaque key which it passes
		// back to the matcher; retaining the complete source also preserves selector groups.
		return SelectorList{
			selectors: [CSSSelector{
				text: selector_text
			}]
			contains_named_namespace: if hook.contains_named_namespace != unsafe { nil } {
				hook.contains_named_namespace(hook.target, selector_text)
			} else {
				false
			}
		}
	}
	mut selectors := []CSSSelector{}
	for raw_selector in selector_text.split(',') {
		selector := raw_selector.trim_space()
		if selector.len == 0 {
			return none
		}
		selectors << CSSSelector{
			text: selector
		}
	}
	if selectors.len == 0 {
		return none
	}
	// A DOM-only consumer may not have installed the CSS bridge. Preserve syntax validation for
	// selector lists, but matching below intentionally fails until a selector engine is registered.
	return SelectorList{
		selectors: selectors
	}
}

fn selector_engine_matches(selector CSSSelector, element &Element, scoping_root &ParentNode) bool {
	if hook := element.document().selector_query_hook() {
		if hook.matches != unsafe { nil } {
			return hook.matches(hook.target, selector.text, element, scoping_root)
		}
	}
	return false
}

// https://dom.spec.whatwg.org/#scope-match-a-selectors-string
fn scope_match_a_selectors_string(node &ParentNode, selector_text string, return_matches ReturnMatches) !NodeList {
	// To scope-match a selectors string selectors against a node, run these steps:
	document := node.as_node().document()
	selector_text_string := selector_text
	mut selectors := SelectorList{}

	// Check the document's parsed selector cache first.
	if selector_text_string in document.selector_query_cache {
		// 2. If s is failure, then throw a "SyntaxError" DOMException.
		selectors = document.selector_query_cache[selector_text_string] or {
			return error('SyntaxError: Failed to parse selector')
		}
	} else {
		// 1. Let s be the result of parse a selector selectors.
		mut maybe_selectors := parse_selector(document, selector_text)

		// "Note: Support for namespaces within selectors is not planned and will not be added."
		if parsed_selectors := maybe_selectors {
			if contains_named_namespace(parsed_selectors) {
				maybe_selectors = none
			}
		}

		mut mutable_document := unsafe { &Document(document) }
		mutable_document.cache_query_selector_result(selector_text_string, maybe_selectors)

		// 2. If s is failure, then throw a "SyntaxError" DOMException.
		selectors = mutable_document.selector_query_cache[selector_text_string] or {
			return error('SyntaxError: Failed to parse selector')
		}
	}

	// 3. Return the result of match a selector against a tree with s and node's root using scoping root node.
	// The owning engine can prepare one matching context for the whole query.
	// Parsing and namespace rejection above still precede this optional path.
	if hook := document.selector_query_hook() {
		if hook.scope_query != unsafe { nil } {
			if nodes := hook.scope_query(hook.target, selector_text, node, return_matches == .first) {
				return NodeList{nodes: nodes}
			}
		}
	}
	mut results := []&Node{}
	results_ptr := &results
	if return_matches == .first {
		node.as_node().visit_subtree(fn [selectors, node, results_ptr] (tree_node &Node) TraversalDecision {
			element := tree_node.as_element() or { return .@continue }
			for selector in selectors.selectors {
				if selector_engine_matches(selector, element, node) {
					dom_ptr_push(results_ptr, element.as_node())
					return .@break
				}
			}
			return .@continue
		})
		if results.len > 0 {
			return NodeList{
				nodes: [results[0]]
			}
		}
		return NodeList{}
	}
	node.as_node().visit_subtree(fn [selectors, node, results_ptr] (tree_node &Node) TraversalDecision {
		element := tree_node.as_element() or { return .@continue }
		for selector in selectors.selectors {
			if selector_engine_matches(selector, element, node) {
				dom_ptr_push(results_ptr, element.as_node())
				break
			}
		}
		return .@continue
	})
	return NodeList{
		nodes: results
	}
}

// https://dom.spec.whatwg.org/#dom-parentnode-queryselector
pub fn (p &ParentNode) query_selector(selector_text string) ?&Element {
	// The querySelector(selectors) method steps are to return the first result of running scope-match a selectors string selectors against this,
	// if the result is not an empty list; otherwise null.
	list := scope_match_a_selectors_string(p, selector_text, .first) or { return none }
	node := list.item(0) or { return none }
	return node.as_element()
}

// https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn (p &ParentNode) query_selector_all(selector_text string) !&NodeList {
	// The querySelectorAll(selectors) method steps are to return the static result of running scope-match a selectors string selectors against this.
	list := scope_match_a_selectors_string(p, selector_text, .all)!
	return &NodeList{
		nodes: list.nodes
	}
}

pub fn (p &ParentNode) first_element_child() ?&Element {
	for child in p.as_node().children {
		if element := child.as_element() {
			return element
		}
	}
	return none
}

pub fn (p &ParentNode) last_element_child() ?&Element {
	children := p.as_node().children
	for i := children.len - 1; i >= 0; i-- {
		if element := children[i].as_element() {
			return element
		}
	}
	return none
}

// https://dom.spec.whatwg.org/#dom-parentnode-childelementcount
pub fn (p &ParentNode) child_element_count() u32 {
	mut count := u32(0)
	for child in p.as_node().children {
		if child.is_element() {
			count++
		}
	}
	return count
}

pub fn (mut p ParentNode) visit_edges(mut visitor CellVisitor) {
	mut node := p.as_mut_node()
	node.visit_edges(mut visitor)
	visitor.visit(p.children_)
}

// https://dom.spec.whatwg.org/#dom-parentnode-children
pub fn (mut p ParentNode) children_collection() &HTMLCollection {
	// The children getter steps are to return an HTMLCollection collection rooted at this matching only element children.
	if p.children_ == unsafe { nil } {
		p.children_ = HTMLCollection.create(&p, .children, always_accept_element, never_sort_elements)
	}
	return p.children_
}

// https://dom.spec.whatwg.org/#concept-getelementsbytagname
pub fn (mut p ParentNode) get_elements_by_tag_name(qualified_name string) &HTMLCollection {
	// 1. If qualifiedName is "*" (U+002A), return a HTMLCollection rooted at root, whose filter matches only descendant elements.
	if qualified_name == '*' {
		return HTMLCollection.create(&p, .descendants, always_accept_element, never_sort_elements)
	}
	root_node := p.as_node()
	// 2. Otherwise, if root's node document is an HTML document, return a HTMLCollection rooted at root, whose filter matches the following descendant elements:
	if root_node.document().document_type() == .html {
		qualified_name_in_ascii_lowercase := to_ascii_lowercase(qualified_name)
		return HTMLCollection.create(&p, .descendants, fn [qualified_name, qualified_name_in_ascii_lowercase] (element &Element) bool {
			// - Whose namespace is the HTML namespace and whose qualified name is qualifiedName, in ASCII lowercase.
			if element.namespace_uri() or { '' } == namespace_html_uri {
				return element.qualified_name_str() == qualified_name_in_ascii_lowercase
			}
			// - Whose namespace is not the HTML namespace and whose qualified name is qualifiedName.
			return element.qualified_name_str() == qualified_name
		}, never_sort_elements)
	}
	// 3. Otherwise, return a HTMLCollection rooted at root, whose filter matches descendant elements whose qualified name is qualifiedName.
	return HTMLCollection.create(&p, .descendants, fn [qualified_name] (element &Element) bool {
		return element.qualified_name_str() == qualified_name
	}, never_sort_elements)
}

// https://dom.spec.whatwg.org/#concept-getelementsbytagnamens
pub fn (mut p ParentNode) get_elements_by_tag_name_ns(namespace_ ?string, local_name string) &HTMLCollection {
	// 1. If namespace is the empty string, set it to null.
	normalized_namespace := if namespace_ or { '' } == '' { ?string(none) } else { namespace_ }
	// 2. If both namespace and localName are "*" (U+002A), return a HTMLCollection rooted at root, whose filter matches descendant elements.
	if normalized_namespace or { '' } == '*' && local_name == '*' {
		return HTMLCollection.create(&p, .descendants, always_accept_element, never_sort_elements)
	}
	// 3. Otherwise, if namespace is "*" (U+002A), return a HTMLCollection rooted at root, whose filter matches descendant elements whose local name is localName.
	if normalized_namespace or { '' } == '*' {
		return HTMLCollection.create(&p, .descendants, fn [local_name] (element &Element) bool {
			return element.local_name() == local_name
		}, never_sort_elements)
	}
	// 4. Otherwise, if localName is "*" (U+002A), return a HTMLCollection rooted at root, whose filter matches descendant elements whose namespace is namespace.
	if local_name == '*' {
		return HTMLCollection.create(&p, .descendants, fn [normalized_namespace] (element &Element) bool {
			return option_string_equal(element.namespace_uri(), normalized_namespace)
		}, never_sort_elements)
	}
	// 5. Otherwise, return a HTMLCollection rooted at root, whose filter matches descendant elements whose namespace is namespace and local name is localName.
	return HTMLCollection.create(&p, .descendants, fn [normalized_namespace, local_name] (element &Element) bool {
		return option_string_equal(element.namespace_uri(), normalized_namespace) && element.local_name() == local_name
	}, never_sort_elements)
}

// https://dom.spec.whatwg.org/#dom-parentnode-prepend
pub fn (mut p ParentNode) prepend(nodes []NodeOrString) ! {
	// 1. Let node be the result of converting nodes into a node given nodes and this's node document.
	mut parent_node := p.as_mut_node()
	node := convert_nodes_to_single_node(nodes, parent_node.document())!
	// 2. Pre-insert node into this before this's first child.
	parent_node.pre_insert(node, parent_node.first_child())!
}

pub fn (mut p ParentNode) append(nodes []NodeOrString) ! {
	// 1. Let node be the result of converting nodes into a node given nodes and this's node document.
	mut parent_node := p.as_mut_node()
	node := convert_nodes_to_single_node(nodes, parent_node.document())!
	// 2. Append node to this.
	parent_node.append_child(node)!
}

pub fn (mut p ParentNode) replace_children(nodes []NodeOrString) ! {
	// 1. Let node be the result of converting nodes into a node given nodes and this's node document.
	mut parent_node := p.as_mut_node()
	node := convert_nodes_to_single_node(nodes, parent_node.document())!
	// 2. Ensure pre-insertion validity of node into this before null.
	parent_node.ensure_pre_insertion_validity(unsafe { nil }, node, none)!
	// 3. Replace all with node within this.
	parent_node.replace_all(node)
}

// https://dom.spec.whatwg.org/#dom-parentnode-movebefore
pub fn (mut p ParentNode) move_before(node &Node, child ?&Node) ! {
	// 1. Let referenceChild be child.
	mut reference_child := ?&Node(none)
	if child_node := child {
		reference_child = unsafe { &Node(child_node) }
	}
	// 2. If referenceChild is node, then set referenceChild to node's next sibling.
	if reference := reference_child {
		if reference == node {
			reference_child = node.next_sibling()
		}
	}
	// 3. Move node into this before referenceChild.
	mut mutable_node := unsafe { &Node(node) }
	mut parent_node := p.as_mut_node()
	mutable_node.move_node(mut parent_node, reference_child)!
}

// https://dom.spec.whatwg.org/#dom-document-getelementsbyclassname
pub fn (mut p ParentNode) get_elements_by_class_name(class_names string) &HTMLCollection {
	list_of_class_names := split_on_ascii_whitespace(class_names)
	quirks_mode := p.as_node().document().in_quirks_mode()
	return HTMLCollection.create(&p, .descendants, fn [list_of_class_names, quirks_mode] (element &Element) bool {
		if list_of_class_names.len == 0 {
			return false
		}
		for name in list_of_class_names {
			if quirks_mode {
				if !element.has_class_case_insensitive(name) {
					return false
				}
			} else if !element.has_class(name) {
				return false
			}
		}
		return true
	}, never_sort_elements)
}

pub fn (p &ParentNode) get_element_by_id(id string) ?&Element {
	node := p.as_node()
	if node.is_connected() {
		// For connected document and shadow root we have a cache that allows fast lookup.
		if node.is_document() {
			document := unsafe { &Document(node) }
			return document.element_by_id_map().get(id, node)
		}
		if shadow_root := node.as_shadow_root() {
			return shadow_root.element_by_id().get(id, node)
		}
	}
	return get_element_by_id_in_subtree(node, id)
}

fn get_element_by_id_in_subtree(node &Node, id string) ?&Element {
	if element := node.as_element() {
		if element_id := element.id() {
			if element_id == id {
				return element
			}
		}
	}
	for child in node.children {
		if found := get_element_by_id_in_subtree(child, id) {
			return found
		}
	}
	return none
}

// --- AbstractRange / StaticRange / Range ---
@[heap]
pub struct AbstractRange {
pub mut:
	start_container_ &Node = unsafe { nil }
	start_offset_    int
	end_container_   &Node = unsafe { nil }
	end_offset_      int
}

pub fn AbstractRange.new(start_container &Node, start_offset int, end_container &Node, end_offset int) &AbstractRange {
	return &AbstractRange{
		start_container_: start_container
		start_offset_: start_offset
		end_container_: end_container
		end_offset_: end_offset
	}
}

pub fn (mut r AbstractRange) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(AbstractRange)
}

pub fn (mut r AbstractRange) visit_edges(mut visitor CellVisitor) {
	visitor.visit(r.start_container_)
	visitor.visit(r.end_container_)
}

pub fn (r &AbstractRange) start() BoundaryPoint {
	return BoundaryPoint{
		node: r.start_container_
		offset: r.start_offset_
	}
}

pub fn (r &AbstractRange) start_container() &Node {
	return r.start_container_
}

pub fn (r &AbstractRange) start_offset() int {
	return r.start_offset_
}

pub fn (r &AbstractRange) end() BoundaryPoint {
	return BoundaryPoint{
		node: r.end_container_
		offset: r.end_offset_
	}
}

pub fn (r &AbstractRange) end_container() &Node {
	return r.end_container_
}

pub fn (r &AbstractRange) end_offset() int {
	return r.end_offset_
}

// https://dom.spec.whatwg.org/#range-collapsed
pub fn (r &AbstractRange) collapsed() bool {
	// A range is collapsed if its start node is its end node and its start offset is its end offset.
	return r.start_container_ == r.end_container_ && r.start_offset_ == r.end_offset_
}

pub fn (r &AbstractRange) equals(other &AbstractRange) bool {
	return r.start_container_ == other.start_container_ && r.start_offset_ == other.start_offset_ && r.end_container_ == other.end_container_ && r.end_offset_ == other.end_offset_
}

pub struct StaticRangeInit {
pub mut:
	start_container &Node = unsafe { nil }
	start_offset    int
	end_container   &Node = unsafe { nil }
	end_offset      int
}

@[heap]
pub struct StaticRange {
	AbstractRange
}

pub fn StaticRange.new(start_container &Node, start_offset int, end_container &Node, end_offset int) &StaticRange {
	return &StaticRange{
		AbstractRange: AbstractRange{
			start_container_: start_container
			start_offset_: start_offset
			end_container_: end_container
			end_offset_: end_offset
		}
	}
}

// https://dom.spec.whatwg.org/#dom-staticrange-staticrange
pub fn StaticRange.construct_impl(init StaticRangeInit) !&StaticRange {
	// 1. If init["startContainer"] or init["endContainer"] is a DocumentType or Attr node, then throw an "InvalidNodeTypeError" DOMException.
	if init.start_container.is_document_type() || init.start_container.is_attribute() {
		return error('InvalidNodeTypeError: startContainer cannot be a DocumentType or Attribute node.')
	}
	if init.end_container.is_document_type() || init.end_container.is_attribute() {
		return error('InvalidNodeTypeError: endContainer cannot be a DocumentType or Attribute node.')
	}
	// 2. Set this's start to (init["startContainer"], init["startOffset"]) and end to (init["endContainer"], init["endOffset"]).
	return StaticRange.new(init.start_container, init.start_offset, init.end_container, init.end_offset)
}

pub fn (mut r StaticRange) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(StaticRange)
}

pub fn Range.create(document &Document) &Range {
	range := &Range{
		start_container_: unsafe { &Node(document) }
		end_container_: unsafe { &Node(document) }
	}
	persistent := platform.enter_persistent()
	dom_live_ranges[u64(voidptr(range))] = range
	platform.leave_persistent(persistent)
	return range
}

pub fn Range.create_from_window(window &Window) &Range {
	document := window.associated_document() or {
		// The C++ constructor receives an HTML::Window whose associated document is guaranteed by the platform object.
		// The current V Window stub can still be created without one, so keep the failure local instead of inventing
		// nonstandard global state.
		return &Range{}
	}
	return Range.create(document)
}

pub fn Range.create_from_boundary_points(start_container &Node, start_offset int, end_container &Node, end_offset int) &Range {
	assert start_offset <= start_container.length()
	assert end_offset <= end_container.length()
	range := &Range{
		start_container_: start_container
		start_offset_: start_offset
		end_container_: end_container
		end_offset_: end_offset
	}
	persistent := platform.enter_persistent()
	dom_live_ranges[u64(voidptr(range))] = range
	platform.leave_persistent(persistent)
	return range
}

pub fn Range.construct_impl(window &Window) &Range {
	return Range.create_from_window(window)
}

pub fn (mut r Range) finalize() {
	dom_live_ranges.delete(u64(voidptr(&r)))
}

pub fn (mut r Range) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(Range)
}

pub fn (mut r Range) visit_edges(mut visitor CellVisitor) {
	visitor.visit(r.start_container_)
	visitor.visit(r.end_container_)
	visitor.visit(r.associated_selection_)
}

pub fn (mut r Range) set_associated_selection(selection ?&Selection) {
	r.associated_selection_ = selection or { unsafe { nil } }
	r.update_associated_selection()
}

pub fn (mut r Range) update_associated_selection() {
	if r.associated_selection_ == unsafe { nil } {
		return
	}
	if r.start_container_ == unsafe { nil } {
		return
	}
	mut document := unsafe { &Document(r.start_container_.document()) }
	if document == unsafe { nil } {
		return
	}
	document.reset_cursor_blink_cycle()
	if paintable := document.unsafe_paintable() {
		paintable.recompute_selection_states(r)
		paintable.set_needs_repaint_with_invalidation(.paint_commands)
	}
	// https://w3c.github.io/selection-api/#selectionchange-event
	// When the selection is dissociated with its range, associated with a new range, or the associated range's boundary
	// point is mutated either by the user or the content script, the user agent must schedule a selectionchange event
	// on document.
	document.set_scheduled_selectionchange_event(true)
	// A live selection mutation outside the edit being recorded closes the
	// current typing coalescence unit.
	document.notify_editing_history_selection_changed()
}

// https://dom.spec.whatwg.org/#concept-range-root
pub fn (r &Range) root() &Node {
	// The root of a live range is the root of its start node.
	return r.start_container_.root()
}

pub fn (r &Range) start() BoundaryPoint {
	return BoundaryPoint{
		node: r.start_container_
		offset: r.start_offset_
	}
}

pub fn (r &Range) start_container() &Node {
	return r.start_container_
}

pub fn (r &Range) start_offset() int {
	return r.start_offset_
}

pub fn (r &Range) end() BoundaryPoint {
	return BoundaryPoint{
		node: r.end_container_
		offset: r.end_offset_
	}
}

pub fn (r &Range) end_container() &Node {
	return r.end_container_
}

pub fn (r &Range) end_offset() int {
	return r.end_offset_
}

// https://dom.spec.whatwg.org/#range-collapsed
pub fn (r &Range) collapsed() bool {
	return r.start_container_ == r.end_container_ && r.start_offset_ == r.end_offset_
}

// https://dom.spec.whatwg.org/#concept-range-bp-position
pub fn position_of_boundary_point_relative_to_other_boundary_point(a BoundaryPoint, b BoundaryPoint) RelativeBoundaryPointPosition {
	// 1. Assert: nodeA and nodeB have the same root.
	// NOTE: Nodes may not share the same root if they belong to different shadow trees, so compare shadow-including roots.
	assert a.node.shadow_including_root() == b.node.shadow_including_root()
	if a.node == b.node {
		// 2. If nodeA is nodeB, then return equal if offsetA is offsetB, before if offsetA is less than offsetB, and after if offsetA is greater than offsetB.
		if a.offset == b.offset {
			return .equal
		}
		if a.offset < b.offset {
			return .before
		}
		return .after
	}
	// 3. If nodeA is following nodeB, then invert the relative position.
	if a.node.is_following(b.node) {
		relative_position := position_of_boundary_point_relative_to_other_boundary_point(b, a)
		if relative_position == .before {
			return .after
		}
		if relative_position == .after {
			return .before
		}
		return .equal
	}
	// 4. If nodeA is an ancestor of nodeB:
	if a.node.is_ancestor_of(b.node) {
		// 1. Let child be nodeB.
		mut child := b.node
		// 2. While child is not a child of nodeA, set child to its parent.
		for !a.node.is_parent_of(child) {
			parent := child.parent() or { break }
			child = unsafe { &Node(parent) }
		}
		// 3. If child's index is less than offsetA, then return after.
		if child.index() < a.offset {
			return .after
		}
	}
	// 5. Return before.
	return .before
}

// https://dom.spec.whatwg.org/#concept-range-bp-set
pub fn (mut r Range) set_start_or_end(node &Node, offset int, start_or_end RangeStartOrEnd) ! {
	// To set the start or end of a range to a boundary point (node, offset), run these steps:
	// 1. If node is a doctype, then throw an "InvalidNodeTypeError" DOMException.
	if node.is_document_type() {
		return error('InvalidNodeTypeError: Node cannot be a DocumentType.')
	}
	// 2. If offset is greater than node's length, then throw an "IndexSizeError" DOMException.
	if offset > node.length() {
		return error('IndexSizeError: Node does not contain a child at offset ${offset}')
	}
	if start_or_end == .start {
		// If these steps were invoked as "set the start":
		// 1. If range's root is not equal to node's root, or if bp is after the range's end, set range's end to bp.
		if r.start_container_ == unsafe { nil } || r.root() != node.root() || position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
			node: node
			offset: offset
		}, r.end()) == .after {
			r.end_container_ = node
			r.end_offset_ = offset
		}
		// 2. Set range's start to bp.
		r.start_container_ = node
		r.start_offset_ = offset
	} else {
		// If these steps were invoked as "set the end":
		// 1. If range's root is not equal to node's root, or if bp is before the range's start, set range's start to bp.
		if r.end_container_ == unsafe { nil } || r.root() != node.root() || position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
			node: node
			offset: offset
		}, r.start()) == .before {
			r.start_container_ = node
			r.start_offset_ = offset
		}
		// 2. Set range's end to bp.
		r.end_container_ = node
		r.end_offset_ = offset
	}
	r.update_associated_selection()
}

// https://dom.spec.whatwg.org/#dom-range-setstart
pub fn (mut r Range) set_start(node &Node, offset int) ! {
	// The setStart(node, offset) method steps are to set the start of this to boundary point (node, offset).
	r.set_start_or_end(node, offset, .start)!
}

// https://dom.spec.whatwg.org/#dom-range-setend
pub fn (mut r Range) set_end(node &Node, offset int) ! {
	// The setEnd(node, offset) method steps are to set the end of this to boundary point (node, offset).
	r.set_start_or_end(node, offset, .end)!
}

// https://dom.spec.whatwg.org/#dom-range-setstartbefore
pub fn (mut r Range) set_start_before(node &Node) ! {
	// 1. Let parent be node's parent.
	parent := node.parent() or {
		// 2. If parent is null, then throw an "InvalidNodeTypeError" DOMException.
		return error('InvalidNodeTypeError: Given node has no parent.')
	}
	// 3. Set the start of this to boundary point (parent, node's index).
	r.set_start_or_end(parent, node.index(), .start)!
}

// https://dom.spec.whatwg.org/#dom-range-setstartafter
pub fn (mut r Range) set_start_after(node &Node) ! {
	parent := node.parent() or { return error('InvalidNodeTypeError: Given node has no parent.') }
	r.set_start_or_end(parent, node.index() + 1, .start)!
}

// https://dom.spec.whatwg.org/#dom-range-setendbefore
pub fn (mut r Range) set_end_before(node &Node) ! {
	parent := node.parent() or { return error('InvalidNodeTypeError: Given node has no parent.') }
	r.set_start_or_end(parent, node.index(), .end)!
}

// https://dom.spec.whatwg.org/#dom-range-setendafter
pub fn (mut r Range) set_end_after(node &Node) ! {
	parent := node.parent() or { return error('InvalidNodeTypeError: Given node has no parent.') }
	r.set_start_or_end(parent, node.index() + 1, .end)!
}

// https://dom.spec.whatwg.org/#dom-range-compareboundarypoints
pub fn (r &Range) compare_boundary_points(how HowToCompareBoundaryPoints, source_range &Range) !int {
	// 1. If how is not one of START_TO_START, START_TO_END, END_TO_END, and END_TO_START, throw.
	// The enum type enforces this in V.
	// 2. If this's root is not the same as sourceRange's root, then throw a "WrongDocumentError" DOMException.
	if r.root() != source_range.root() {
		return error('WrongDocumentError: This range is not in the same tree as the source range.')
	}
	mut this_point := BoundaryPoint{}
	mut other_point := BoundaryPoint{}
	// 3. Select this point and other point based on how.
	match how {
		.start_to_start {
			this_point = r.start()
			other_point = source_range.start()
		}
		.start_to_end {
			this_point = r.end()
			other_point = source_range.start()
		}
		.end_to_end {
			this_point = r.end()
			other_point = source_range.end()
		}
		.end_to_start {
			this_point = r.start()
			other_point = source_range.end()
		}
	}

	// 4. If the position of this point relative to other point is before/equal/after, return -1/0/1.
	return match position_of_boundary_point_relative_to_other_boundary_point(this_point, other_point) {
		.before { -1 }
		.equal { 0 }
		.after { 1 }
	}
}

// https://dom.spec.whatwg.org/#concept-range-select
pub fn (mut r Range) select(node &Node) ! {
	// 1. Let parent be node's parent.
	parent := node.parent() or {
		// 2. If parent is null, then throw an "InvalidNodeTypeError" DOMException.
		return error('InvalidNodeTypeError: Given node has no parent.')
	}
	// 3. Let index be node's index.
	index := node.index()
	// 4. Set range's start to boundary point (parent, index).
	r.start_container_ = parent
	r.start_offset_ = index
	// 5. Set range's end to boundary point (parent, index plus 1).
	r.end_container_ = parent
	r.end_offset_ = index + 1
	r.update_associated_selection()
}

// https://dom.spec.whatwg.org/#dom-range-selectnode
pub fn (mut r Range) select_node(node &Node) ! {
	// The selectNode(node) method steps are to select node within this.
	r.select(node)!
}

// https://dom.spec.whatwg.org/#dom-range-collapse
pub fn (mut r Range) collapse(to_start bool) {
	// The collapse(toStart) method steps are to, if toStart is true, set end to start; otherwise set start to end.
	if to_start {
		r.end_container_ = r.start_container_
		r.end_offset_ = r.start_offset_
	} else {
		r.start_container_ = r.end_container_
		r.start_offset_ = r.end_offset_
	}
	r.update_associated_selection()
}

// https://dom.spec.whatwg.org/#dom-range-selectnodecontents
pub fn (mut r Range) select_node_contents(node &Node) ! {
	// 1. If node is a doctype, throw an "InvalidNodeTypeError" DOMException.
	if node.is_document_type() {
		return error('InvalidNodeTypeError: Node cannot be a DocumentType.')
	}
	// 2. Let length be the length of node.
	length := node.length()
	// 3. Set start to the boundary point (node, 0).
	r.start_container_ = node
	r.start_offset_ = 0
	// 4. Set end to the boundary point (node, length).
	r.end_container_ = node
	r.end_offset_ = length
	r.update_associated_selection()
}

pub fn (r &Range) clone_range() &Range {
	return Range.create_from_boundary_points(r.start_container_, r.start_offset_, r.end_container_, r.end_offset_)
}

// https://dom.spec.whatwg.org/#dom-range-commonancestorcontainer
pub fn (r &Range) common_ancestor_container() &Node {
	// 1. Let container be start node.
	mut container := r.start_container_
	// 2. While container is not an inclusive ancestor of end node, let container be container's parent.
	for !container.is_inclusive_ancestor_of(r.end_container_) {
		container = container.parent() or { break }
	}
	// 3. Return container.
	return container
}

// https://dom.spec.whatwg.org/#dom-range-detach
pub fn (r &Range) detach() {
	_ = r
	// The detach() method steps are to do nothing.
}

// https://dom.spec.whatwg.org/#dom-range-intersectsnode
pub fn (r &Range) intersects_node(node &Node) bool {
	// 1. If node's root is different from this's root, return false.
	if node.root() != r.root() {
		return false
	}
	// 2. Let parent be node's parent.
	parent := node.parent() or {
		// 3. If parent is null, return true.
		return true
	}
	// 4. Let offset be node's index.
	offset := node.index()
	// 5. If (parent, offset) is before end and (parent, offset plus 1) is after start, return true.
	relative_position_to_end := position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
		node: parent
		offset: offset
	}, r.end())
	relative_position_to_start := position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
		node: parent
		offset: offset + 1
	}, r.start())
	if relative_position_to_end == .before && relative_position_to_start == .after {
		return true
	}
	// 6. Return false.
	return false
}

// https://dom.spec.whatwg.org/#dom-range-ispointinrange
pub fn (r &Range) is_point_in_range(node &Node, offset int) !bool {
	// 1. If node's root is different from this's root, return false.
	if node.root() != r.root() {
		return false
	}
	// 2. If node is a doctype, then throw an "InvalidNodeTypeError" DOMException.
	if node.is_document_type() {
		return error('InvalidNodeTypeError: Node cannot be a DocumentType.')
	}
	// 3. If offset is greater than node's length, then throw an "IndexSizeError" DOMException.
	if offset > node.length() {
		return error('IndexSizeError: Node does not contain a child at offset ${offset}')
	}
	// 4. If (node, offset) is before start or after end, return false.
	relative_position_to_start := position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
		node: node
		offset: offset
	}, r.start())
	relative_position_to_end := position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
		node: node
		offset: offset
	}, r.end())
	if relative_position_to_start == .before || relative_position_to_end == .after {
		return false
	}
	// 5. Return true.
	return true
}

// https://dom.spec.whatwg.org/#dom-range-comparepoint
pub fn (r &Range) compare_point(node &Node, offset int) !int {
	// 1. If node's root is different from this's root, then throw a "WrongDocumentError" DOMException.
	if node.root() != r.root() {
		return error('WrongDocumentError: Given node is not in the same document as the range.')
	}
	// 2. If node is a doctype, then throw an "InvalidNodeTypeError" DOMException.
	if node.is_document_type() {
		return error('InvalidNodeTypeError: Node cannot be a DocumentType.')
	}
	// 3. If offset is greater than node's length, then throw an "IndexSizeError" DOMException.
	if offset > node.length() {
		return error('IndexSizeError: Node does not contain a child at offset ${offset}')
	}
	// 4. If (node, offset) is before start, return -1.
	relative_position_to_start := position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
		node: node
		offset: offset
	}, r.start())
	if relative_position_to_start == .before {
		return -1
	}
	// 5. If (node, offset) is after end, return 1.
	relative_position_to_end := position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
		node: node
		offset: offset
	}, r.end())
	if relative_position_to_end == .after {
		return 1
	}
	// 6. Return 0.
	return 0
}

// https://dom.spec.whatwg.org/#dom-range-stringifier
pub fn (r &Range) to_string() string {
	// 1. Let s be the empty string.
	mut builder := ''
	// 2. If this's start node is this's end node and it is a Text node, then return the substring of that Text node's data.
	if r.start_container_ == r.end_container_ && r.start_container_.is_text_node_for_range_stringifier() {
		if text := r.start_container_.character_data() {
			return text.substring_data(r.start_offset_, r.end_offset_ - r.start_offset_) or { '' }
		}
	}
	// 3. If this's start node is a Text node, then append the substring of that node's data from this's start offset until the end to s.
	if r.start_container_.is_text_node_for_range_stringifier() {
		if text := r.start_container_.character_data() {
			builder += text.substring_data(r.start_offset_, text.length_in_utf16_code_units() - r.start_offset_) or { '' }
		}
	}
	// 4. Append the concatenation of the data of all Text nodes that are contained in this, in tree order, to s.
	for node in r.contained_nodes() {
		if node.is_text_node_for_range_stringifier() {
			if text := node.character_data() {
				builder += text.data_
			}
		}
	}
	// 5. If this's end node is a Text node, then append the substring of that node's data from its start until this's end offset to s.
	if r.end_container_.is_text_node_for_range_stringifier() {
		if text := r.end_container_.character_data() {
			builder += text.substring_data(0, r.end_offset_) or { '' }
		}
	}
	// 6. Return s.
	return builder
}

fn (n &Node) is_text_node_for_range_stringifier() bool {
	return n.is_text() || n.is_cdata_section()
}

// https://dom.spec.whatwg.org/#dom-range-extractcontents
pub fn (mut r Range) extract_contents() !&DocumentFragment {
	return r.extract()
}

// https://dom.spec.whatwg.org/#concept-range-extract
pub fn (mut r Range) extract() !&DocumentFragment {
	// 1. Let fragment be a new DocumentFragment node whose node document is range's start node's node document.
	fragment := new_document_fragment(r.start_container_.document())
	mut fragment_node := unsafe { &Node(fragment) }
	// 2. If range is collapsed, then return fragment.
	if r.collapsed() {
		return fragment
	}
	// 3. Let original start/end node and offset be range's boundary points.
	original_start_node := r.start_container_
	original_start_offset := r.start_offset_
	original_end_node := r.end_container_
	original_end_offset := r.end_offset_
	// 4. If original start node is original end node and it is a CharacterData node, then clone and remove the substring.
	if original_start_node == original_end_node && original_start_node.is_character_data() {
		clone := original_start_node.clone_node(none, false, none)!
		mut clone_node := unsafe { &Node(clone) }
		if mut clone_data := clone_node.character_data_mut() {
			if data := original_start_node.character_data() {
				clone_data.set_data(data.substring_data(original_start_offset, original_end_offset - original_start_offset)!)
			}
		}
		fragment_node.append_child(clone)!
		mut mutable_original_start_node := unsafe { &Node(original_start_node) }
		if mut data := mutable_original_start_node.character_data_mut() {
			data.replace_data_with_mutation_steps(original_start_offset, original_end_offset - original_start_offset, '')!
		}
		return fragment
	}
	mut common_ancestor := unsafe { &Node(original_start_node) }
	for !common_ancestor.is_inclusive_ancestor_of(original_end_node) {
		common_ancestor = common_ancestor.parent_node() or {
			return error('InvalidStateError: Range boundary nodes do not share an ancestor')
		}
	}
	mut first_partially_contained_child := ?&Node(none)
	if !original_start_node.is_inclusive_ancestor_of(original_end_node) {
		for child in common_ancestor.children {
			if r.partially_contains_node(child) {
				first_partially_contained_child = unsafe { &Node(child) }
				break
			}
		}
	}
	mut last_partially_contained_child := ?&Node(none)
	if !original_end_node.is_inclusive_ancestor_of(original_start_node) {
		for i := common_ancestor.children.len - 1; i >= 0; i-- {
			child := common_ancestor.children[i]
			if r.partially_contains_node(child) {
				last_partially_contained_child = unsafe { &Node(child) }
				break
			}
		}
	}
	mut contained_children := []&Node{}
	for child in common_ancestor.children {
		if r.contains_node(child) {
			contained_children << child
		}
	}
	for child in contained_children {
		if child.is_document_type() {
			return error('HierarchyRequestError: Contained child is a DocumentType')
		}
	}
	mut new_node := unsafe { &Node(original_start_node) }
	mut new_offset := original_start_offset
	if !original_start_node.is_inclusive_ancestor_of(original_end_node) {
		mut reference_node := unsafe { &Node(original_start_node) }
		for reference_node.parent_node() != none && !(reference_node.parent_node() or { break }).is_inclusive_ancestor_of(original_end_node) {
			reference_node = reference_node.parent_node() or { break }
		}
		new_node = reference_node.parent_node() or { new_node }
		new_offset = reference_node.index() + 1
	}
	// Collapse before any of the extraction mutations. Keeping this live range
	// at its final boundary lets the normal mutation steps adjust that boundary
	// while partially-contained and contained nodes are changed.
	r.set_start(new_node, new_offset)!
	r.set_end(new_node, new_offset)!
	if first_child := first_partially_contained_child {
		if first_child.is_character_data() {
			clone := original_start_node.clone_node(none, false, none)!
			mut clone_node := unsafe { &Node(clone) }
			if mut clone_data := clone_node.character_data_mut() {
				if data := original_start_node.character_data() {
					clone_data.set_data(data.substring_data(original_start_offset, original_start_node.length() - original_start_offset)!)
				}
			}
			fragment_node.append_child(clone)!
			mut mutable_original_start_node := unsafe { &Node(original_start_node) }
			if mut data := mutable_original_start_node.character_data_mut() {
				data.replace_data_with_mutation_steps(original_start_offset, original_start_node.length() - original_start_offset, '')!
			}
		} else {
			clone := first_child.clone_node(none, false, none)!
			fragment_node.append_child(clone)!
			mut subrange := Range.create_from_boundary_points(original_start_node, original_start_offset, first_child, first_child.length())
			subfragment := subrange.extract()!
			mut clone_node := unsafe { &Node(clone) }
			clone_node.append_child(subfragment.as_node())!
		}
	}
	for contained_child in contained_children {
		fragment_node.append_child(contained_child)!
	}
	if last_child := last_partially_contained_child {
		if last_child.is_character_data() {
			clone := original_end_node.clone_node(none, false, none)!
			mut clone_node := unsafe { &Node(clone) }
			if mut clone_data := clone_node.character_data_mut() {
				if data := original_end_node.character_data() {
					clone_data.set_data(data.substring_data(0, original_end_offset)!)
				}
			}
			fragment_node.append_child(clone)!
			mut mutable_original_end_node := unsafe { &Node(original_end_node) }
			if mut data := mutable_original_end_node.character_data_mut() {
				data.replace_data_with_mutation_steps(0, original_end_offset, '')!
			}
		} else {
			clone := last_child.clone_node(none, false, none)!
			fragment_node.append_child(clone)!
			mut subrange := Range.create_from_boundary_points(last_child, 0, original_end_node, original_end_offset)
			subfragment := subrange.extract()!
			mut clone_node := unsafe { &Node(clone) }
			clone_node.append_child(subfragment.as_node())!
		}
	}
	return fragment
}

// https://dom.spec.whatwg.org/#contained
pub fn (r &Range) contains_node(node &Node) bool {
	// A node node is contained in a live range range if node's root is range's root,
	if node.root() != r.root() {
		return false
	}
	// and (node, 0) is after range's start,
	if position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
		node: node
		offset: 0
	}, r.start()) != .after {
		return false
	}
	// and (node, node's length) is before range's end.
	if position_of_boundary_point_relative_to_other_boundary_point(BoundaryPoint{
		node: node
		offset: node.length()
	}, r.end()) != .before {
		return false
	}
	return true
}

// https://dom.spec.whatwg.org/#partially-contained
pub fn (r &Range) partially_contains_node(node &Node) bool {
	// A node is partially contained in a live range if it's an inclusive ancestor of the live range's start node but not its end node, or vice versa.
	return node.is_inclusive_ancestor_of(r.start_container_) != node.is_inclusive_ancestor_of(r.end_container_)
}

// https://dom.spec.whatwg.org/#dom-range-insertnode
pub fn (mut r Range) insert_node(node &Node) ! {
	r.insert(node)!
}

// https://dom.spec.whatwg.org/#concept-range-insert
pub fn (mut r Range) insert(node &Node) ! {
	// 1. If range's start node is a ProcessingInstruction or Comment node, is a Text node whose parent is null, or is node, then throw.
	if r.start_container_.node_type == .processing_instruction_node || r.start_container_.is_comment() || (r.start_container_.is_exclusive_text() && r.start_container_.parent_node() == none) || r.start_container_ == node {
		return error('HierarchyRequestError: Range has inappropriate start node for insertion')
	}
	// 2. Let referenceNode be null.
	mut reference_node := ?&Node(none)
	// 3. If range's start node is a Text node, set referenceNode to that Text node.
	if r.start_container_.is_exclusive_text() {
		reference_node = r.start_container_
	} else {
		// 4. Otherwise, set referenceNode to the child of start node whose index is start offset, and null if there is no such child.
		reference_node = r.start_container_.child_at_index(r.start_offset_)
	}
	// 5. Let parent be range's start node if referenceNode is null, and referenceNode's parent otherwise.
	parent := if ref := reference_node {
		ref.parent() or { r.start_container_ }
	} else {
		r.start_container_
	}
	// 6. Ensure pre-insertion validity of node into parent before referenceNode.
	parent.ensure_pre_insertion_validity(unsafe { nil }, node, reference_node)!
	// 7. If range's start node is a Text node, set referenceNode to the result of splitting it with offset range's start offset.
	if r.start_container_.is_exclusive_text() {
		mut text := unsafe { &Text(r.start_container_) }
		reference_node = text.split_text(r.start_offset_)!.as_node()
	}
	// 8. If node is referenceNode, set referenceNode to its next sibling.
	if ref := reference_node {
		if ref == node {
			reference_node = ref.next_sibling()
		}
	}
	// 9. If node's parent is non-null, then remove node.
	if node.parent() != none {
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.remove(false)
	}
	// 10. Let newOffset be parent's length if referenceNode is null, and referenceNode's index otherwise.
	mut new_offset := if ref := reference_node { ref.index() } else { parent.length() }
	// 11. Increase newOffset by node's length if node is a DocumentFragment node, and one otherwise.
	if node.is_document_fragment() {
		new_offset += node.length()
	} else {
		new_offset++
	}
	// 12. Pre-insert node into parent before referenceNode.
	mut mutable_parent := unsafe { &Node(parent) }
	mutable_parent.pre_insert(node, reference_node)!
	// 13. If range is collapsed, then set range's end to (parent, newOffset).
	if r.collapsed() {
		r.set_end(parent, new_offset)!
	}
}

// https://dom.spec.whatwg.org/#dom-range-surroundcontents
pub fn (mut r Range) surround_contents(new_parent &Node) ! {
	// 1. If a non-Text node is partially contained in this, then throw an "InvalidStateError" DOMException.
	mut start_non_text_node := r.start_container_
	if start_non_text_node.is_exclusive_text() {
		start_non_text_node = start_non_text_node.parent_node() or { start_non_text_node }
	}
	mut end_non_text_node := r.end_container_
	if end_non_text_node.is_exclusive_text() {
		end_non_text_node = end_non_text_node.parent_node() or { end_non_text_node }
	}
	if start_non_text_node != end_non_text_node {
		return error('InvalidStateError: Non-Text node is partially contained in range.')
	}
	// 2. If newParent is a Document, DocumentType, or DocumentFragment node, then throw an "InvalidNodeTypeError" DOMException.
	if new_parent.is_document() || new_parent.is_document_type() || new_parent.is_document_fragment() {
		return error('InvalidNodeTypeError: Invalid parent node type')
	}
	// 3. Let fragment be the result of extracting this.
	fragment := r.extract()!
	// 4. If newParent has children, then replace all with null within newParent.
	mut mutable_new_parent := unsafe { &Node(new_parent) }
	if new_parent.has_children() {
		mutable_new_parent.replace_all(none)
	}
	// 5. Insert newParent into this.
	r.insert(new_parent)!
	// 6. Append fragment to newParent.
	mutable_new_parent.append_child(fragment.as_node())!
	// 7. Select newParent within this.
	r.select(new_parent)!
}

// https://dom.spec.whatwg.org/#dom-range-clonecontents
pub fn (mut r Range) clone_contents() !&DocumentFragment {
	return r.clone_the_contents()
}

// https://dom.spec.whatwg.org/#concept-range-clone
pub fn (mut r Range) clone_the_contents() !&DocumentFragment {
	// 1. Let fragment be a new DocumentFragment node whose node document is range's start node's node document.
	fragment := new_document_fragment(r.start_container_.document())
	mut fragment_node := unsafe { &Node(fragment) }
	// 2. If range is collapsed, then return fragment.
	if r.collapsed() {
		return fragment
	}
	// 3. Let original start/end node and offset be range's boundary points.
	original_start_node := r.start_container_
	original_start_offset := r.start_offset_
	original_end_node := r.end_container_
	original_end_offset := r.end_offset_
	// 4. If original start node is original end node and it is a CharacterData node, then clone the selected substring.
	if original_start_node == original_end_node && original_start_node.is_character_data() {
		clone := original_start_node.clone_node(none, false, none)!
		mut clone_node := unsafe { &Node(clone) }
		if mut clone_data := clone_node.character_data_mut() {
			if data := original_start_node.character_data() {
				clone_data.set_data(data.substring_data(original_start_offset, original_end_offset - original_start_offset)!)
			}
		}
		fragment_node.append_child(clone)!
		return fragment
	}
	mut common_ancestor := unsafe { &Node(original_start_node) }
	for !common_ancestor.is_inclusive_ancestor_of(original_end_node) {
		common_ancestor = common_ancestor.parent_node() or {
			return error('InvalidStateError: Range boundary nodes do not share an ancestor')
		}
	}
	mut first_partially_contained_child := ?&Node(none)
	if !original_start_node.is_inclusive_ancestor_of(original_end_node) {
		for child in common_ancestor.children {
			if r.partially_contains_node(child) {
				first_partially_contained_child = unsafe { &Node(child) }
				break
			}
		}
	}
	mut last_partially_contained_child := ?&Node(none)
	if !original_end_node.is_inclusive_ancestor_of(original_start_node) {
		for i := common_ancestor.children.len - 1; i >= 0; i-- {
			child := common_ancestor.children[i]
			if r.partially_contains_node(child) {
				last_partially_contained_child = unsafe { &Node(child) }
				break
			}
		}
	}
	mut contained_children := []&Node{}
	for child in common_ancestor.children {
		if r.contains_node(child) {
			contained_children << child
		}
	}
	for child in contained_children {
		if child.is_document_type() {
			return error('HierarchyRequestError: Contained child is a DocumentType')
		}
	}
	if first_child := first_partially_contained_child {
		if first_child.is_character_data() {
			clone := original_start_node.clone_node(none, false, none)!
			mut clone_node := unsafe { &Node(clone) }
			if mut clone_data := clone_node.character_data_mut() {
				if data := original_start_node.character_data() {
					clone_data.set_data(data.substring_data(original_start_offset, original_start_node.length() - original_start_offset)!)
				}
			}
			fragment_node.append_child(clone)!
		} else {
			clone := first_child.clone_node(none, false, none)!
			fragment_node.append_child(clone)!
			mut subrange := Range.create_from_boundary_points(original_start_node, original_start_offset, first_child, first_child.length())
			subfragment := subrange.clone_the_contents()!
			mut clone_node := unsafe { &Node(clone) }
			clone_node.append_child(subfragment.as_node())!
		}
	}
	for contained_child in contained_children {
		clone := contained_child.clone_node(none, true, none)!
		fragment_node.append_child(clone)!
	}
	if last_child := last_partially_contained_child {
		if last_child.is_character_data() {
			clone := original_end_node.clone_node(none, false, none)!
			mut clone_node := unsafe { &Node(clone) }
			if mut clone_data := clone_node.character_data_mut() {
				if data := original_end_node.character_data() {
					clone_data.set_data(data.substring_data(0, original_end_offset)!)
				}
			}
			fragment_node.append_child(clone)!
		} else {
			clone := last_child.clone_node(none, false, none)!
			fragment_node.append_child(clone)!
			mut subrange := Range.create_from_boundary_points(last_child, 0, original_end_node, original_end_offset)
			subfragment := subrange.clone_the_contents()!
			mut clone_node := unsafe { &Node(clone) }
			clone_node.append_child(subfragment.as_node())!
		}
	}
	return fragment
}

// https://dom.spec.whatwg.org/#dom-range-deletecontents
pub fn (mut r Range) delete_contents() ! {
	// 1. If this is collapsed, then return.
	if r.collapsed() {
		return
	}
	// 2. Let original start/end node and offset be this's boundary points.
	original_start_node := r.start_container_
	original_start_offset := r.start_offset_
	original_end_node := r.end_container_
	original_end_offset := r.end_offset_
	// 3. If original start node is original end node and it is a CharacterData node, replace data and return.
	if original_start_node == original_end_node && original_start_node.is_character_data() {
		mut mutable_original_start_node := unsafe { &Node(original_start_node) }
		if mut data := mutable_original_start_node.character_data_mut() {
			data.replace_data(original_start_offset, original_end_offset - original_start_offset, '')!
		}
		return
	}
	// 4. Let nodes to remove be all contained nodes, omitting any node whose parent is also contained.
	mut nodes_to_remove := []&Node{}
	nodes_to_remove_ptr := &nodes_to_remove
	r.for_each_contained(fn [r, nodes_to_remove_ptr] (node &Node) TraversalDecision {
		if parent := node.parent_node() {
			if r.contains_node(parent) {
				return .@continue
			}
		}
		dom_ptr_push(nodes_to_remove_ptr, node)
		return .@continue
	})
	// 5-6. Compute the new boundary point.
	mut new_node := unsafe { &Node(original_start_node) }
	mut new_offset := original_start_offset
	if !original_start_node.is_inclusive_ancestor_of(original_end_node) {
		mut reference_node := unsafe { &Node(original_start_node) }
		for {
			parent := reference_node.parent_node() or { break }
			if parent.is_inclusive_ancestor_of(original_end_node) {
				break
			}
			reference_node = unsafe { &Node(parent) }
		}
		if parent := reference_node.parent_node() {
			new_node = unsafe { &Node(parent) }
			new_offset = 1 + reference_node.index()
		}
	}
	// 7. Collapse before any deletion mutations so the live boundary is updated
	// by those mutations along with every other live range.
	r.set_start(new_node, new_offset)!
	r.set_end(new_node, new_offset)!
	// 8. If original start node is CharacterData, remove data after start offset.
	if original_start_node.is_character_data() {
		mut mutable_original_start_node := unsafe { &Node(original_start_node) }
		if mut data := mutable_original_start_node.character_data_mut() {
			data.replace_data(original_start_offset, original_start_node.length() - original_start_offset, '')!
		}
	}
	// 9. For each node in nodes to remove, in tree order, remove node.
	for node in nodes_to_remove {
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.remove(false)
	}
	// 10. If original end node is CharacterData, remove data before end offset.
	if original_end_node.is_character_data() {
		mut mutable_original_end_node := unsafe { &Node(original_end_node) }
		if mut data := mutable_original_end_node.character_data_mut() {
			data.replace_data(0, original_end_offset, '')!
		}
	}
}

pub struct DOMRect {
pub mut:
	x      f64
	y      f64
	width  f64
	height f64
}

pub struct DOMRectList {
pub mut:
	rects []DOMRect
}

pub fn DOMRect.construct_impl(x f64, y f64, width f64, height f64) DOMRect {
	return DOMRect{
		x: x
		y: y
		width: width
		height: height
	}
}

pub fn DOMRectList.create(rects []DOMRect) &DOMRectList {
	return &DOMRectList{
		rects: rects
	}
}

pub fn (l &DOMRectList) length() int {
	return l.rects.len
}

pub fn (l &DOMRectList) item(index int) ?DOMRect {
	if index < 0 || index >= l.rects.len {
		return none
	}
	return l.rects[index]
}

fn next_after_range_subtree(node &Node) ?&Node {
	mut current := ?&Node(node)
	for current != none {
		candidate := current or { break }
		if next := candidate.next_sibling() {
			return next
		}
		current = candidate.parent_node()
	}
	return none
}

// https://drafts.csswg.org/cssom-view/#dom-element-getclientrects
// https://drafts.csswg.org/cssom-view/#extensions-to-the-range-interface
pub fn (r &Range) get_client_rects() &DOMRectList {
	// 1. Return an empty DOMRectList object if the range is not in the document.
	mut document := unsafe { &Document(r.start_container_.document()) }
	if document.navigable() == none {
		return DOMRectList.create([])
	}
	document.update_layout(.range_get_client_rects)

	mut rects := []DOMRect{}
	mut did_update_paint_and_hit_testing_properties := false
	// FIXME: take Range collapsed into consideration.
	// 2. Iterate the nodes included in Range.
	mut start_node := ?&Node(r.start_container_)
	if !r.start_container_.is_text() {
		if start_child := r.start_container_.child_at_index(r.start_offset_) {
			start_node = start_child
		} else if last_child := r.start_container_.last_child() {
			start_node = next_after_range_subtree(last_child)
		} else {
			start_node = r.start_container_.next_in_pre_order(none)
		}
	}
	mut end_node := ?&Node(r.end_container_)
	if !r.end_container_.is_text() {
		// end offset shouldn't be 0.
		if r.end_offset_ == 0 {
			return DOMRectList.create([])
		}
		end_node = r.end_container_.child_at_index(r.end_offset_ - 1)
	}
	start := start_node or { return DOMRectList.create([]) }
	end := end_node or { return DOMRectList.create([]) }
	end_next := end.next_in_pre_order(none)
	for node := ?&Node(start); node != none;  {
		current := node or { break }
		if stop := end_next {
			if current == stop {
				break
			}
		}
		selection_state := if current == start && current == end {
			if r.start_offset_ == r.end_offset_ { SelectionState.none } else { SelectionState.start_and_end }
		} else if current == start {
			SelectionState.start
		} else if current == end {
			SelectionState.end
		} else {
			SelectionState.full
		}
		if element := current.as_element() {
			// 1. For each element selected by the range, whose parent is not selected by the range,
			//    include the border areas returned by invoking getClientRects() on the element.
			parent_is_contained := if parent := current.parent() {
				r.contains_node(parent)
			} else {
				false
			}
			if r.contains_node(current) && !parent_is_contained {
				for rect in element.get_client_rects() {
					rects << DOMRect.construct_impl(rect.x_, rect.y_, rect.width_, rect.height_)
				}
			}
		} else if current.is_text() && selection_state != .none {
			if !did_update_paint_and_hit_testing_properties {
				document.update_paint_and_hit_testing_properties_if_needed()
				did_update_paint_and_hit_testing_properties = true
			}
			if paintable := document.paintable() {
				rects << paintable.text_range_rects(current, selection_state, r.start_offset_,
					r.end_offset_)
			}
		}
		node = current.next_in_pre_order(none)
	}
	return DOMRectList.create(rects)
}

// https://w3c.github.io/csswg-drafts/cssom-view/#dom-range-getboundingclientrect
pub fn (r &Range) get_bounding_client_rect() DOMRect {
	// 1. Let list be the result of invoking getClientRects() on element.
	list := r.get_client_rects()
	// 2. If the list is empty return a DOMRect object whose x, y, width and height members are zero.
	if list.length() == 0 {
		return DOMRect.construct_impl(0, 0, 0, 0)
	}
	// 3. If all rectangles in list have zero width or height, return the first rectangle in list.
	first := list.item(0) or { return DOMRect.construct_impl(0, 0, 0, 0) }
	mut all_zero := true
	for rect in list.rects {
		if rect.width != 0 && rect.height != 0 {
			all_zero = false
			break
		}
	}
	if all_zero {
		return first
	}
	// 4. Otherwise, return the smallest rectangle that includes all non-zero rectangles.
	mut left := first.x
	mut top := first.y
	mut right := first.x + first.width
	mut bottom := first.y + first.height
	for rect in list.rects {
		if rect.width == 0 || rect.height == 0 {
			continue
		}
		if rect.x < left {
			left = rect.x
		}
		if rect.y < top {
			top = rect.y
		}
		if rect.x + rect.width > right {
			right = rect.x + rect.width
		}
		if rect.y + rect.height > bottom {
			bottom = rect.y + rect.height
		}
	}
	return DOMRect.construct_impl(left, top, right - left, bottom - top)
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-range-createcontextualfragment
pub fn (r &Range) create_contextual_fragment(fragment string) !&DocumentFragment {
	// 1. Let compliantString be the result of invoking the Get Trusted Type compliant string algorithm.
	compliant_string := r.start_container_.document().trusted_types_compliant_html(fragment, 'range-create-contextual-fragment')!
	// 2. Let node be this's start node.
	node := r.start_container_
	// 3. Let element be null.
	mut element := ?&Element(none)
	// 4. If node implements Element, set element to node.
	if node_element := node.as_element() {
		element = unsafe { &Element(node_element) }
	} else if

	// 5. Otherwise, if node implements Text or Comment node, set element to node's parent element.
	node.is_text() || node.is_comment() {
		element = node.parent_element()
	}
	// 6. If element is null or is an HTML html element, use a synthetic body element.
	if context_element := element {
		if context_element.is_html_element() && context_element.local_name() == 'html' {
			element = create_element(node.document(), 'body', namespace_html_, none, none, false)!
		}
	} else {
		element = create_element(node.document(), 'body', namespace_html_, none, none, false)!
	}
	context_element := element or {
		return error('InvalidStateError: Could not determine a context element')
	}

	// 7. Parse in Fragment mode so script elements are not marked parser-inserted or already started.
	return context_element.parse_fragment_with_scripting_mode(compliant_string, .fragment)
}

pub fn (r &Range) for_each_contained(callback fn(&Node) TraversalDecision) {
	for node in r.contained_nodes() {
		if callback(node) == .@break {
			return
		}
	}
}

pub fn (r &Range) contained_nodes() []&Node {
	mut nodes := []&Node{}
	mut end := ?&Node(r.end_container_)
	for end != none {
		end_node := end or { break }
		if end_node.next_sibling() != none {
			break
		}
		end = end_node.parent()
	}
	if end_node := end {
		end = end_node.next_sibling()
	}
	mut node := ?&Node(r.start_container_)
	for node != none {
		current := node or { break }
		if end_node := end {
			if current == end_node {
				break
			}
		}
		if r.contains_node(current) {
			nodes << current
		}
		node = current.next_in_pre_order(none)
	}
	return nodes
}

pub fn Range.live_ranges() []&Range {
	return dom_live_ranges.values()
}

// --- Position ---
pub fn Position.create(node &Node, offset int) &Position {
	return &Position{
		node_: node
		offset_: offset
	}
}

pub fn (mut p Position) visit_edges(mut visitor CellVisitor) {
	visitor.visit(p.node_)
}

pub fn (p &Position) node() ?&Node {
	if p.node_ == unsafe { nil } {
		return none
	}
	return p.node_
}

pub fn (p &Position) offset() int {
	return p.offset_
}

pub fn (p &Position) equals(other &Position) bool {
	return p.node_ == other.node_ && p.offset_ == other.offset_
}

pub fn (p &Position) to_string() string {
	if node := p.node() {
		return 'DOM::Position(${node.node_name()} (${ptr_str(node)})), ${p.offset()})'
	}
	return 'DOM::Position(<null>, 0)'
}

fn ptr_str(ptr voidptr) string {
	return '${ptr}'
}
