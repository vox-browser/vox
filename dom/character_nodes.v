// Copyright (c) 2018-2025, the Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/DOM/Attr.cpp/.h,
// CharacterData.cpp/.h, Text.cpp/.h, Comment.cpp/.h,
// CDATASection.cpp/.h, ProcessingInstruction.cpp/.h,
// DocumentType.cpp/.h, DocumentFragment.cpp/.h, and
// QualifiedName.cpp/.h.
module dom

import strings
import vunicode
import encoding.utf8

// --- QualifiedName ---
pub fn QualifiedName.new(local_name string, prefix ?string, namespace_ ?string) QualifiedName {
	return QualifiedName{
		local_name: local_name
		prefix_: prefix
		namespace_: namespace_
		lowercased_local_name: to_ascii_lowercase(local_name)
	}
}

fn to_ascii_lowercase(value string) string {
	mut first_uppercase := -1
	for i, byte in value {
		if byte >= `A` && byte <= `Z` {
			first_uppercase = i
			break
		}
	}
	if first_uppercase < 0 {
		return value
	}
	mut bytes := value.bytes()
	for i := first_uppercase; i < bytes.len; i++ {
		byte := bytes[i]
		if byte >= `A` && byte <= `Z` {
			bytes[i] = byte + 0x20
		}
	}
	return bytes.bytestr()
}

fn qualified_name_hash_string(value string) u64 {
	mut hash := u64(1469598103934665603)
	for byte in value {
		hash ^= u64(byte)
		hash *= 1099511628211
	}
	return hash
}

fn qualified_name_pair_int_hash(a u64, b u64) u64 {
	return a ^ (b + 0x9e3779b97f4a7c15 + (a << 6) + (a >> 2))
}

fn qualified_name_hash_impl(local_name string, prefix ?string, namespace_ ?string) u64 {
	mut hash := qualified_name_hash_string(local_name)
	if p := prefix {
		hash = qualified_name_pair_int_hash(hash, qualified_name_hash_string(p))
	}
	if ns := namespace_ {
		hash = qualified_name_pair_int_hash(hash, qualified_name_hash_string(ns))
	}
	return hash
}

pub fn (q &QualifiedName) hash() u64 {
	return qualified_name_hash_impl(q.local_name, q.prefix_, q.namespace_)
}

// https://dom.spec.whatwg.org/#concept-attribute-qualified-name
// https://dom.spec.whatwg.org/#concept-element-qualified-name
pub fn (q &QualifiedName) make_internal_string() string {
	// This is possible to do according to the spec: "User agents could have this as an internal slot as an optimization."
	if p := q.prefix_ {
		return '${p}:${q.local_name}'
	}
	return q.local_name
}

pub fn (mut q QualifiedName) set_prefix(value ?string) {
	q.prefix_ = value
}

// --- Shared node casts ---
pub fn (c &CharacterData) as_node() &Node {
	return unsafe { &Node(c) }
}

pub fn (c &Comment) as_node() &Node {
	return unsafe { &Node(c) }
}

pub fn (c &CDATASection) as_node() &Node {
	return unsafe { &Node(c) }
}

pub fn (p &ProcessingInstruction) as_node() &Node {
	return unsafe { &Node(p) }
}

pub fn (a &Attr) as_node() &Node {
	return unsafe { &Node(a) }
}

pub fn (d &DocumentType) as_node() &Node {
	return unsafe { &Node(d) }
}

// --- Attr ---
pub fn Attr.create(document &Document, qualified_name QualifiedName, value string, owner_element ?&Element) &Attr {
	return assign_unique_node_id(&Attr{
		Node: Node{
			node_type: .attribute_node
			document_: document
			unique_id_: UniqueNodeID(0)
		}
		name_: qualified_name.as_string()
		value_: value
		local_name_: qualified_name.local_name
		prefix__: qualified_name.prefix_
		namespace_uri_: qualified_name.namespace_
		owner_element_: owner_element or { unsafe { nil } }
	})
}

pub fn Attr.create_with_local_name(document &Document, local_name string, value string, owner_element ?&Element) &Attr {
	return Attr.create(document, QualifiedName.new(local_name, none, none), value, owner_element)
}

pub fn (a &Attr) clone(document &Document) &Attr {
	return Attr.create(document, QualifiedName.new(a.local_name_, a.prefix__, a.namespace_uri_), a.value_, none)
}

pub fn (mut a Attr) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(Attr);
	// Base::initialize(realm);
}

pub fn (mut a Attr) visit_edges(mut visitor CellVisitor) {
	a.Node.visit_edges(mut visitor)
	visitor.visit(a.owner_element_)
}

pub fn (mut a Attr) set_owner_element(owner_element ?&Element) {
	a.owner_element_ = owner_element or { unsafe { nil } }
}

// Always returns true: https://dom.spec.whatwg.org/#dom-attr-specified
pub fn (a &Attr) specified() bool {
	return true
}

// https://dom.spec.whatwg.org/#set-an-existing-attribute-value
pub fn (mut a Attr) set_value_with_attribute_steps(value string) ! {
	// 1. If attribute's element is null, then set attribute's value to value and return.
	if a.owner_element() == none {
		a.value_ = value
		return
	}

	// 2. Let element be attribute's element.
	element := a.owner_element() or {
		a.value_ = value
		return
	}

	// 3. Let verifiedValue be the result of calling get Trusted Types-compliant attribute value with
	//    attribute's local name, attribute's namespace, element, and value.
	verified_value := get_trusted_types_compliant_attribute_value(a.local_name_, a.namespace_uri_, element, value)!

	// 4. If attribute's element is null, then set attribute's value to verifiedValue, and return.
	if a.owner_element() == none {
		a.value_ = verified_value
		return
	}

	// 5. Change attribute to verifiedValue.
	a.change_attribute(verified_value)
}

// https://dom.spec.whatwg.org/#concept-element-attributes-change
pub fn (mut a Attr) change_attribute(value string) {
	// 1. Let oldValue be attribute's value.
	old_value := a.value_

	// 2. Set attribute's value to value.
	a.value_ = value

	// 3. Handle attribute changes for attribute with attribute's element, oldValue, and value.
	element := a.owner_element() or { return }
	a.handle_attribute_changes(element, old_value, a.value_)
}

// https://dom.spec.whatwg.org/#handle-attribute-changes
pub fn (a &Attr) handle_attribute_changes(element &Element, old_value ?string, new_value ?string) {
	// 1. Queue a mutation record of "attributes" for element with attribute's local name,
	//    attribute's namespace, oldValue, << >>, << >>, null, and null.
	mut element_node := unsafe { &Node(element) }
	element_node.queue_mutation_record(.attributes, a.local_name_, a.namespace_uri_, old_value, []&Node{}, []&Node{}, unsafe { nil }, unsafe { nil })

	mut mutable_element := unsafe { &Element(element) }

	// 2. If element is custom, then enqueue a custom element callback reaction with element, callback name
	//    "attributeChangedCallback", and << attribute's local name, oldValue, newValue, attribute's namespace >>.
	if element.is_custom() {
		mutable_element.enqueue_an_attribute_changed_callback_reaction(a.local_name_, old_value,
			new_value, a.namespace_uri_)
	}

	// 3. Run the attribute change steps with element, attribute's local name, oldValue, newValue, and attribute's namespace.
	mutable_element.run_attribute_change_steps(a.local_name_, old_value, new_value, a.namespace_uri_)
}

fn get_trusted_types_compliant_attribute_value(local_name string, namespace_uri ?string, element &Element, value string) !string {
	return element.document().trusted_types_compliant_attribute_value(element, local_name, namespace_uri, value)!
}

// --- CharacterData ---
pub fn CharacterData.new(document &Document, node_type NodeType, data string) &CharacterData {
	return assign_unique_node_id(&CharacterData{
		Node: Node{
			node_type: node_type
			document_: document
			unique_id_: UniqueNodeID(0)
		}
		data_: data
	})
}

pub fn (mut c CharacterData) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(CharacterData);
	// Base::initialize(realm);
}

pub fn (c &CharacterData) length() int {
	return c.length_in_utf16_code_units()
}

// https://dom.spec.whatwg.org/#concept-cd-substring
pub fn (c &CharacterData) substring_data(offset int, count int) !string {
	// 1. Let length be node's length.
	length := c.length_in_utf16_code_units()

	// 2. If offset is greater than length, then throw an "IndexSizeError" DOMException.
	if offset < 0 || offset > length {
		return error('IndexSizeError: Substring offset out of range')
	}
	if count < 0 {
		return error('IndexSizeError: Substring count out of range')
	}

	// 3. If offset plus count is greater than length, return a string whose value is the code units from the offsetth code unit
	//    to the end of node's data, and then return.
	if offset + count > length {
		return string_from_utf16_code_units(utf16_code_units_from_string(c.data_)[offset..])
	}

	// 4. Return a string whose value is the code units from the offsetth code unit to the offset+countth code unit in node's data.
	return string_from_utf16_code_units(utf16_code_units_from_string(c.data_)[offset..offset + count])
}

// https://dom.spec.whatwg.org/#concept-cd-replace
pub fn (mut c CharacterData) replace_data_with_mutation_steps(offset int, count int, data string) ! {
	if c.as_node().document() != unsafe { nil } {
		c.as_node().document().notify_editing_history_dom_mutation()
	}
	// 1. Let length be node's length.
	length := c.length_in_utf16_code_units()

	// 2. If offset is greater than length, then throw an "IndexSizeError" DOMException.
	if offset < 0 || offset > length {
		return error('IndexSizeError: Replacement offset out of range')
	}
	if count < 0 {
		return error('IndexSizeError: Replacement count out of range')
	}

	// 3. If offset plus count is greater than length, then set count to length minus offset.
	actual_count := if offset + count > length { length - offset } else { count }

	// 5. Insert data into node's data after offset code units.
	// 6. Let delete offset be offset + data's length.
	// 7. Starting from delete offset code units, remove count code units from node's data.
	old_data := c.data_
	if offset == 0 && actual_count == length && utf8.validate_str(data) {
		// Parser text flushes replace a complete node. Well-formed UTF-8 needs
		// no UTF-16 splice or normalization, and the node owns its sole copy.
		c.data_ = data.clone()
	} else {
		mut full_data := utf16_code_units_from_string(c.data_)
		replacement_data := utf16_code_units_from_string(data)
		before_data := full_data[..offset].clone()
		after_data := full_data[offset + actual_count..].clone()
		full_data = before_data.clone()
		full_data << replacement_data
		full_data << after_data
		c.data_ = string_from_utf16_code_units(full_data)
	}

	mut node := unsafe { &Node(&c) }

	// 4. Queue a mutation record of "characterData" for node with null, null, node's data, << >>, << >>, null, and null.
	// NOTE: We do this later so that the mutation observer may notify UI clients of this node's new value.
	node.queue_mutation_record(.character_data, none, none, old_data, []&Node{}, []&Node{}, unsafe { nil }, unsafe { nil })

	mut selection_range_to_preserve := unsafe { voidptr(nil) }
	if c.data_ == old_data && node.document().preserve_selection_offsets_during_identical_character_data_replacement() {
		if selection := node.document().get_selection() {
			if selection_range := selection.range() {
				selection_range_to_preserve = voidptr(selection_range)
			}
		}
	}

	// 8. For each live range whose start node is node and start offset is greater than offset but less than or equal to
	//    offset plus count, set its start offset to offset.
	// 9. For each live range whose end node is node and end offset is greater than offset but less than or equal to
	//    offset plus count, set its end offset to offset.
	// 10. For each live range whose start node is node and start offset is greater than offset plus count, increase its
	//     start offset by data's length and decrease it by count.
	// 11. For each live range whose end node is node and end offset is greater than offset plus count, increase its end
	//     offset by data's length and decrease it by count.
	update_live_ranges_for_character_data_replacement(node, offset, actual_count, utf16_code_unit_length(data),
		selection_range_to_preserve)

	// 12. If node's parent is non-null, then run the children changed steps for node's parent.
	if parent := node.parent() {
		mut mutable_parent := unsafe { &Node(parent) }
		mutable_parent.children_changed(ChildrenChangedMetadata{
			type_: .mutation
			node: node
		})
	}

	// OPTIMIZATION: If the characters are the same, we can skip the remainder of this function.
	if c.data_ == old_data {
		// Live ranges may still have moved; caches keyed on the version must
		// observe their new offsets.
		doc := node.document()
		if doc != unsafe { nil } {
			mut mutable_doc := unsafe { &Document(doc) }
			mutable_doc.bump_character_data_version()
		}
		return
	}

	// DOM/CharacterData.cpp: first-letter source ranges are fixed while building
	// the tree. Rebuild their owning subtree when text changes its match.
	if node.is_text() {
		if parent := node.parent() {
			if owner := parent.first_letter_owner_for_layout_subtree_from(parent) {
				mut owner_node := unsafe { &Node(owner.as_node()) }
				owner_node.set_needs_layout_tree_update(true, .character_data_replace_data)
			}
		}
		whitespace_changed := character_data_is_ascii_whitespace(old_data) != character_data_is_ascii_whitespace(c.data_)
		if layout_node := node.unsafe_layout_node() {
			if layout_node.is_text_node() && layout_node.text_has_source_range_ {
				if owner := layout_node.first_letter_owner() {
					mut owner_node := unsafe { &Node(owner.as_node()) }
					owner_node.set_needs_layout_tree_update(true, .character_data_replace_data)
				} else if parent := node.parent() {
					mut parent_node := unsafe { &Node(parent) }
					parent_node.set_needs_layout_tree_update(true, .character_data_replace_data)
				}
			} else if layout_node.is_text_node() {
				mut mutable_layout := unsafe { &LayoutNode(layout_node) }
				mutable_layout.invalidate_text_for_rendering()
				mutable_layout.set_needs_layout_update(.character_data_replace_data)
				if whitespace_changed { node.set_needs_layout_tree_update(true, .character_data_replace_data) }
			}
		} else if whitespace_changed && node.is_connected() {
			if parent := node.parent() {
				mut parent_node := unsafe { &Node(parent) }
				parent_node.set_needs_layout_tree_update(true, .character_data_replace_data)
			}
		}
	}

	doc := node.document()
	if doc != unsafe { nil } {
		mut mutable_doc := unsafe { &Document(doc) }
		mutable_doc.bump_character_data_version()
	}

	if c.grapheme_segmenter_ != unsafe { nil } {
		c.grapheme_segmenter_.set_segmented_text(c.data_)
	}
	// The cached segmenter may be the ASCII-only fast path. Re-pick an
	// implementation lazily against the replacement data.
	c.line_segmenter_ = unsafe { nil }
	if c.word_segmenter_ != unsafe { nil } {
		c.word_segmenter_.set_segmented_text(c.data_)
	}

	for ancestor := node.parent_element(); ancestor != none;  {
		mut current := unsafe { &Element(ancestor or { break }) }
		if direction := current.dir() {
			if direction == .auto_ {
				current.as_node().for_each_shadow_including_inclusive_descendant(fn (descendant &Node) TraversalDecision {
					if element := descendant.as_element() {
						mut mutable_element := unsafe { &Element(element) }
						mutable_element.set_needs_style_update(true)
					}
					return .@continue
				})
				auto_direction_element_node := current.as_node()
				scopes := auto_direction_element_node.observing_style_scopes()
				record_auto_directionality_invalidation(scopes.first, auto_direction_element_node)
				for scope in scopes.additional {
					record_auto_directionality_invalidation(scope, auto_direction_element_node)
				}
				schedule_has_invalidation_for_inherited_attribute_change(current, 'dir')
			}
		}
		ancestor = current.as_node().parent_element()
	}
}

fn record_auto_directionality_invalidation(scope &StyleScope, node &Node) {
	mut mutable_scope := unsafe { &StyleScope(scope) }
	mutable_scope.record_pending_has_invalidation_mutation_properties(node, [
		InvalidationProperty{
			type_: .pseudo_class
			pseudo_class_name: 'dir'
		},
		InvalidationProperty{
			type_: .pseudo_class
			pseudo_class_name: 'empty'
		},
	])
}

fn utf16_code_units_from_string(value string) []u16 {
	mut code_units := []u16{}
	for r in value.runes() {
		code_point := u32(r)
		if code_point <= 0xffff {
			code_units << u16(code_point)
			continue
		}
		scalar := code_point - 0x10000
		code_units << u16(0xd800 + (scalar >> 10))
		code_units << u16(0xdc00 + (scalar & 0x3ff))
	}
	return code_units
}

fn character_data_is_ascii_whitespace(value string) bool {
	for index := 0; index < value.len; index++ {
		if !is_ascii_whitespace(value[index]) { return false }
	}
	return true
}

fn string_from_utf16_code_units(code_units []u16) string {
	mut builder := strings.new_builder(code_units.len)
	mut index := 0
	for index < code_units.len {
		code_unit := code_units[index]
		if code_unit >= 0xd800 && code_unit <= 0xdbff && index + 1 < code_units.len {
			next_code_unit := code_units[index + 1]
			if next_code_unit >= 0xdc00 && next_code_unit <= 0xdfff {
				high := u32(code_unit) - 0xd800
				low := u32(next_code_unit) - 0xdc00
				builder.write_rune(rune(0x10000 + ((high << 10) | low)))
				index += 2
				continue
			}
		}
		if code_unit >= 0xd800 && code_unit <= 0xdfff {
			// V strings are UTF-8 and cannot represent lone UTF-16 surrogates; keep the
			// UTF-16 algorithm boundary explicit and substitute U+FFFD for isolated units.
			builder.write_rune(rune(0xfffd))
		} else {
			builder.write_rune(rune(code_unit))
		}
		index++
	}
	return builder.str()
}

pub fn substring_by_utf16_offsets(value string, start int, end int) ?string {
	code_units := utf16_code_units_from_string(value)
	if start < 0 || end < start || end > code_units.len {
		return none
	}
	return string_from_utf16_code_units(code_units[start..end])
}

// https://dom.spec.whatwg.org/#dom-characterdata-appenddata
pub fn (mut c CharacterData) append_data(data string) ! {
	// The appendData(data) method steps are to replace data with node this, offset this's length, count 0, and data data.
	c.replace_data_with_mutation_steps(c.length_in_utf16_code_units(), 0, data)!
}

// https://dom.spec.whatwg.org/#dom-characterdata-insertdata
pub fn (mut c CharacterData) insert_data(offset int, data string) ! {
	// The insertData(offset, data) method steps are to replace data with node this, offset offset, count 0, and data data.
	c.replace_data_with_mutation_steps(offset, 0, data)!
}

// https://dom.spec.whatwg.org/#dom-characterdata-deletedata
pub fn (mut c CharacterData) delete_data(offset int, count int) ! {
	// The deleteData(offset, count) method steps are to replace data with node this, offset offset, count count, and data the empty string.
	c.replace_data_with_mutation_steps(offset, count, '')!
}

pub fn (c &CharacterData) grapheme_segmenter() &Segmenter {
	mut mutable_character_data := unsafe { &CharacterData(c) }
	if mutable_character_data.grapheme_segmenter_ == unsafe { nil } {
		mut document := unsafe { &Document(c.as_node().document()) }
		mutable_character_data.grapheme_segmenter_ = document.grapheme_segmenter().clone()
		mutable_character_data.grapheme_segmenter_.set_segmented_text(c.data_)
	}
	return mutable_character_data.grapheme_segmenter_
}

pub fn (c &CharacterData) line_segmenter() &Segmenter {
	mut mutable_character_data := unsafe { &CharacterData(c) }
	if mutable_character_data.line_segmenter_ == unsafe { nil } {
		if ascii_segmenter := Segmenter.try_create_for_ascii_line(c.data_) {
			mutable_character_data.line_segmenter_ = ascii_segmenter
		} else {
			mut document := unsafe { &Document(c.as_node().document()) }
			mutable_character_data.line_segmenter_ = document.line_segmenter().clone()
			mutable_character_data.line_segmenter_.set_segmented_text(c.data_)
		}
	}
	return mutable_character_data.line_segmenter_
}

pub fn (c &CharacterData) word_segmenter() &Segmenter {
	mut mutable_character_data := unsafe { &CharacterData(c) }
	if mutable_character_data.word_segmenter_ == unsafe { nil } {
		mut document := unsafe { &Document(c.as_node().document()) }
		mutable_character_data.word_segmenter_ = document.word_segmenter().clone()
		mutable_character_data.word_segmenter_.set_segmented_text(c.data_)
	}
	return mutable_character_data.word_segmenter_
}

fn update_live_ranges_for_character_data_replacement(node &Node, offset int, count int, data_length int, range_to_preserve voidptr) {
	end_offset := offset + count
	delta := data_length - count
	for _, live_range in dom_live_ranges {
		mut range := unsafe { &Range(live_range) }
		if voidptr(range) == range_to_preserve {
			continue
		}
		if range.start_container_ == node {
			if range.start_offset_ > offset && range.start_offset_ <= end_offset {
				range.start_offset_ = offset
			} else if range.start_offset_ > end_offset {
				range.start_offset_ += delta
			}
		}
		if range.end_container_ == node {
			if range.end_offset_ > offset && range.end_offset_ <= end_offset {
				range.end_offset_ = offset
			} else if range.end_offset_ > end_offset {
				range.end_offset_ += delta
			}
		}
	}
}

// --- Text ---
pub fn Text.new(document &Document, data string) &Text {
	return Text.new_with_type(document, .text_node, data)
}

pub fn Text.new_with_type(document &Document, node_type NodeType, data string) &Text {
	return assign_unique_node_id(&Text{
		CharacterData: CharacterData{
			Node: Node{
				node_type: node_type
				document_: document
				unique_id_: UniqueNodeID(0)
			}
			data_: data
		}
	})
}

pub fn (mut t Text) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(Text);
	// Base::initialize(realm);
}

pub fn (mut t Text) visit_edges(mut visitor CellVisitor) {
	// Base::visit_edges(visitor);
	// SlottableMixin::visit_edges(visitor);
	mut node := unsafe { &Node(&t) }
	node.visit_edges(mut visitor)
}

// https://dom.spec.whatwg.org/#dom-text-text
pub fn Text.construct_impl(document &Document, data string) !&Text {
	// The new Text(data) constructor steps are to set this's data to data and this's node document to current global object's associated Document.
	return Text.new(document, data)
}

pub fn (t &Text) max_length() ?int {
	return t.max_length_
}

pub fn (mut t Text) set_max_length(max_length ?int) {
	t.max_length_ = max_length
}

pub fn (t &Text) is_password_input() bool {
	return t.is_password_input_
}

pub fn (mut t Text) set_is_password_input(value bool) {
	t.is_password_input_ = value
}

// https://dom.spec.whatwg.org/#dom-text-splittext
// https://dom.spec.whatwg.org/#concept-text-split
pub fn (mut t Text) split_text(offset int) !&Text {
	// 1. Let length be node's length.
	length := t.length()

	// 2. If offset is greater than length, then throw an "IndexSizeError" DOMException.
	if offset < 0 || offset > length {
		return error('IndexSizeError: Split offset is greater than length')
	}

	// 3. Let count be length minus offset.
	count := length - offset

	// 4. Let new data be the result of substringing data with node node, offset offset, and count count.
	new_data := t.CharacterData.substring_data(offset, count)!

	// 5. Let new node be a new Text node, with the same node document as node. Set new node's data to new data.
	new_node := Text.new(t.as_node().document(), new_data)

	// 6. Let parent be node's parent.
	parent := t.as_node().parent()

	// 7. If parent is not null, then:
	if parent_node := parent {
		// 1. Insert new node into parent before node's next sibling.
		mut mutable_parent := unsafe { &Node(parent_node) }
		mutable_parent.insert_before(new_node.as_node(), t.as_node().next_sibling(), false)

		// 2. For each live range whose start node is node and start offset is greater than offset, set its start node
		//    to new node and decrease its start offset by offset.
		// 3. For each live range whose end node is node and end offset is greater than offset, set its end node to new
		//    node and decrease its end offset by offset.
		// 4. For each live range whose start node is parent and start offset is equal to the index of node plus 1,
		//    increase its start offset by 1.
		// 5. For each live range whose end node is parent and end offset is equal to the index of node plus 1, increase
		//    its end offset by 1.
		update_live_ranges_for_text_split(t.as_node(), new_node.as_node(), parent_node, offset)
	}

	// 8. Replace data with node node, offset offset, count count, and data the empty string.
	mut character_data := unsafe { &CharacterData(&t) }
	character_data.replace_data_with_mutation_steps(offset, count, '')!

	// 9. Return new node.
	return new_node
}

// https://dom.spec.whatwg.org/#dom-text-wholetext
pub fn (t &Text) whole_text() string {
	// https://dom.spec.whatwg.org/#contiguous-text-nodes
	// The contiguous Text nodes of a node node are node, node's previous sibling Text node, if any, and its contiguous
	// Text nodes, and node's next sibling Text node, if any, and its contiguous Text nodes, avoiding any duplicates.
	mut nodes := []&Text{}

	nodes << t

	mut current_node := t.as_node().previous_sibling()
	for current_node != none {
		current := current_node or { break }
		if !(current.is_text() || current.is_cdata_section()) {
			break
		}
		nodes << unsafe { &Text(current) }
		current_node = current.previous_sibling()
	}

	// Reverse nodes so they are in tree order.
	nodes.reverse_in_place()

	current_node = t.as_node().next_sibling()
	for current_node != none {
		current := current_node or { break }
		if !(current.is_text() || current.is_cdata_section()) {
			break
		}
		nodes << unsafe { &Text(current) }
		current_node = current.next_sibling()
	}

	mut builder := strings.new_builder(0)
	for text_node in nodes {
		builder.write_string(text_node.data())
	}

	return builder.str()
}

// https://html.spec.whatwg.org/multipage/dom.html#text-node-directionality
pub fn (t &Text) directionality() ?Directionality {
	// 1. If text's data does not contain a code point whose bidirectional character type is L, AL, or R, then return null.
	// 2. Let codePoint be the first code point in text's data whose bidirectional character type is L, AL, or R.
	mut found_character_bidi_class := ?UnicodeBidiClass(none)
	for r in t.data().runes() {
		code_point := u32(r)
		bidi_class := unicode_bidirectional_class(code_point)
		if bidi_class == .left_to_right || bidi_class == .right_to_left_arabic || bidi_class == .right_to_left {
			found_character_bidi_class = bidi_class
			break
		}
	}
	bidi_class := found_character_bidi_class or { return none }

	// 3. If codePoint is of bidirectional character type AL or R, then return 'rtl'.
	if bidi_class == .right_to_left_arabic || bidi_class == .right_to_left {
		return .rtl
	}

	// 4. If codePoint is of bidirectional character type L, then return 'ltr'.
	return .ltr
}

fn update_live_ranges_for_text_split(node &Node, new_node &Node, parent &Node, offset int) {
	node_inserted_after_index := node.index() + 1
	for _, live_range in dom_live_ranges {
		mut range := unsafe { &Range(live_range) }
		if range.start_container_ == node && range.start_offset_ > offset {
			range.start_container_ = new_node
			range.start_offset_ -= offset
		}
		if range.end_container_ == node && range.end_offset_ > offset {
			range.end_container_ = new_node
			range.end_offset_ -= offset
		}
		if range.start_container_ == parent && range.start_offset_ == node_inserted_after_index {
			range.start_offset_++
		}
		if range.end_container_ == parent && range.end_offset_ == node_inserted_after_index {
			range.end_offset_++
		}
	}
}

pub enum UnicodeBidiClass {
	left_to_right
	right_to_left
	european_number
	european_number_separator
	european_number_terminator
	arabic_number
	common_number_separator
	block_separator
	segment_separator
	white_space_neutral
	other_neutral
	left_to_right_embedding
	left_to_right_override
	right_to_left_arabic
	right_to_left_embedding
	right_to_left_override
	pop_directional_format
	dir_non_spacing_mark
	boundary_neutral
	first_strong_isolate
	left_to_right_isolate
	right_to_left_isolate
	pop_directional_isolate
}

pub fn unicode_bidirectional_class(code_point u32) UnicodeBidiClass {
	// DOM directionality and layout consume the same bundled Bidi_Class data.
	return match vunicode.bidi_class(code_point) {
		0 { .left_to_right } // U_LEFT_TO_RIGHT
		1 { .right_to_left } // U_RIGHT_TO_LEFT
		2 { .european_number } // U_EUROPEAN_NUMBER
		3 { .european_number_separator } // U_EUROPEAN_NUMBER_SEPARATOR
		4 { .european_number_terminator } // U_EUROPEAN_NUMBER_TERMINATOR
		5 { .arabic_number } // U_ARABIC_NUMBER
		6 { .common_number_separator } // U_COMMON_NUMBER_SEPARATOR
		7 { .block_separator } // U_BLOCK_SEPARATOR
		8 { .segment_separator } // U_SEGMENT_SEPARATOR
		9 { .white_space_neutral } // U_WHITE_SPACE_NEUTRAL
		10 { .other_neutral } // U_OTHER_NEUTRAL
		11 { .left_to_right_embedding } // U_LEFT_TO_RIGHT_EMBEDDING
		12 { .left_to_right_override } // U_LEFT_TO_RIGHT_OVERRIDE
		13 { .right_to_left_arabic } // U_RIGHT_TO_LEFT_ARABIC
		14 { .right_to_left_embedding } // U_RIGHT_TO_LEFT_EMBEDDING
		15 { .right_to_left_override } // U_RIGHT_TO_LEFT_OVERRIDE
		16 { .pop_directional_format } // U_POP_DIRECTIONAL_FORMAT
		17 { .dir_non_spacing_mark } // U_DIR_NON_SPACING_MARK
		18 { .boundary_neutral } // U_BOUNDARY_NEUTRAL
		19 { .first_strong_isolate } // U_FIRST_STRONG_ISOLATE
		20 { .left_to_right_isolate } // U_LEFT_TO_RIGHT_ISOLATE
		21 { .right_to_left_isolate } // U_RIGHT_TO_LEFT_ISOLATE
		22 { .pop_directional_isolate } // U_POP_DIRECTIONAL_ISOLATE
		else { .boundary_neutral }
	}
}

fn is_ltr_code_point_for_directionality(code_point u32) bool {
	return unicode_bidirectional_class(code_point) == .left_to_right
}

fn is_rtl_code_point_for_directionality(code_point u32) bool {
	bidi_class := unicode_bidirectional_class(code_point)
	return bidi_class == .right_to_left_arabic || bidi_class == .right_to_left
}

// --- Comment ---
pub fn Comment.new(document &Document, data string) &Comment {
	return assign_unique_node_id(&Comment{
		CharacterData: CharacterData{
			Node: Node{
				node_type: .comment_node
				document_: document
				unique_id_: UniqueNodeID(0)
			}
			data_: data
		}
	})
}

// https://dom.spec.whatwg.org/#dom-comment-comment
pub fn Comment.construct_impl(document &Document, data string) !&Comment {
	return Comment.new(document, data)
}

pub fn (mut c Comment) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(Comment);
	// Base::initialize(realm);
}

pub fn (c &Comment) node_name() string {
	return '#comment'
}

// --- CDATASection ---
pub fn CDATASection.new(document &Document, data string) &CDATASection {
	return assign_unique_node_id(&CDATASection{
		Text: Text{
			CharacterData: CharacterData{
				Node: Node{
					node_type: .cdata_section_node
					document_: document
					unique_id_: UniqueNodeID(0)
				}
				data_: data
			}
		}
	})
}

pub fn (mut c CDATASection) finalize() {
	// Destructor is default in the C++ implementation.
}

pub fn (mut c CDATASection) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(CDATASection);
	// Base::initialize(realm);
}

pub fn (c &CDATASection) node_name() string {
	return '#cdata-section'
}

// --- ProcessingInstruction ---
pub fn ProcessingInstruction.new(document &Document, data string, target string) &ProcessingInstruction {
	return assign_unique_node_id(&ProcessingInstruction{
		CharacterData: CharacterData{
			Node: Node{
				node_type: .processing_instruction_node
				document_: document
				unique_id_: UniqueNodeID(0)
			}
			data_: data
		}
		target_: target
	})
}

pub fn (mut p ProcessingInstruction) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(ProcessingInstruction);
	// Base::initialize(realm);
}

pub fn (p &ProcessingInstruction) node_name() string {
	return p.target_
}

// --- DocumentType ---
pub fn DocumentType.create(document &Document) &DocumentType {
	return DocumentType.new(document)
}

pub fn DocumentType.new(document &Document) &DocumentType {
	return assign_unique_node_id(&DocumentType{
		Node: Node{
			node_type: .document_type_node
			document_: document
			unique_id_: UniqueNodeID(0)
		}
	})
}

pub fn (mut d DocumentType) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(DocumentType);
	// Base::initialize(realm);
}

pub fn (d &DocumentType) node_name() string {
	return d.name()
}

pub fn (d &DocumentType) name() string {
	return d.name_
}

pub fn (mut d DocumentType) set_name(name string) {
	d.name_ = name
}

pub fn (d &DocumentType) public_id() string {
	return d.public_id_
}

pub fn (mut d DocumentType) set_public_id(public_id string) {
	d.public_id_ = public_id
}

pub fn (d &DocumentType) system_id() string {
	return d.system_id_
}

pub fn (mut d DocumentType) set_system_id(system_id string) {
	d.system_id_ = system_id
}

// https://dom.spec.whatwg.org/#valid-doctype-name
pub fn is_valid_doctype_name(name string) bool {
	// A string is a valid doctype name if it does not contain ASCII whitespace, U+0000 NULL, or U+003E (>).
	for byte in name.bytes() {
		if byte in [`\t`, `\n`, 0x0c, `\r`, ` `, 0, `>`] {
			return false
		}
	}
	return true
}

// --- DocumentFragment ---
pub fn DocumentFragment.new(document &Document) &DocumentFragment {
	return assign_unique_node_id(&DocumentFragment{
		ParentNode: ParentNode{
			Node: Node{
				node_type: .document_fragment_node
				document_: document
				unique_id_: UniqueNodeID(0)
			}
		}
	})
}

pub fn (mut d DocumentFragment) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(DocumentFragment);
	// Base::initialize(realm);
}

pub fn (mut d DocumentFragment) visit_edges(mut visitor CellVisitor) {
	d.ParentNode.visit_edges(mut visitor)
	visitor.visit(d.host_)
}

pub fn (mut d DocumentFragment) set_host(element ?&Element) {
	d.host_ = element or { unsafe { nil } }
}

// https://dom.spec.whatwg.org/#dom-documentfragment-documentfragment
pub fn DocumentFragment.construct_impl(document &Document) !&DocumentFragment {
	return DocumentFragment.new(document)
}
