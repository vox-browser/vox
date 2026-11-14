module libjsdom

import css
import dom
import libjs
import platform

fn (mut host Host) wrap_node(node &dom.Node) libjs.Value {
	if wrapper := host.wrappers[node.unique_id()] { return libjs.Value.from_object(wrapper) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	prototype := if node.is_element() {
		host.element_prototype
	} else if node.is_document() {
		host.document_prototype
	} else {
		host.node_prototype
	}
	mut object := libjs.Object.create(host.realm, prototype)
	object.class_name = if node.is_element() {
		'Element'
	} else if node.is_document() {
		'Document'
	} else {
		'Node'
	}
	host.wrappers[node.unique_id()] = object
	host.nodes[voidptr(object)] = node
	return libjs.Value.from_object(object)
}

fn (host &Host) node(mut vm libjs.VM) !&dom.Node {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if node := host.nodes[voidptr(vm.this_value().as_object())] { return node }
	}
	return vm.throw_error(.type_error, 'DOM method called on incompatible receiver')
}

fn (host &Host) element(mut vm libjs.VM) !&dom.Element {
	node := host.node(mut vm)!
	return node.as_element() or { return vm.throw_error(.type_error, 'Element method called on incompatible receiver') }
}

fn (mut host Host) install_nodes() ! {
	mut node := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.node_prototype = node
	mut element := libjs.Object.create(host.realm, node)
	host.element_prototype = element
	mut document := libjs.Object.create(host.realm, node)
	host.document_prototype = document
	mut collection_prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.collection_prototype = collection_prototype
	host.accessor(mut collection_prototype, 'length', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_f64(f64(host.collection_receiver(mut vm)!.length()))
	}, unsafe { nil })
	for name in ['item', 'namedItem'] {
		host.method(mut collection_prototype, name, 1, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			collection := host.collection_receiver(mut vm)!
			mut owner := unsafe { &Host(host) }
			mut element := ?&dom.Element(none)
			if name == 'item' {
				element = collection.item(int(vm.argument(0).to_u32(mut vm)!))
			} else {
				element = collection.named_item(vm.argument(0).to_primitive_string(mut vm)!.str())
			}
			return if found := element { owner.wrap_node(found.as_node()) } else { libjs.js_null() }
		})
	}
	for name in ['parentNode', 'parentElement', 'nextSibling', 'nextElementSibling',
		'previousElementSibling', 'ownerDocument', 'nodeName', 'nodeType', 'textContent'] {
		getter := fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut owner := unsafe { &Host(host) }
			actual := host.node(mut vm)!
			match name {
				'nodeName' {
					return libjs.Value.from_string(vm.create_string_from_str(actual.node_name()))
				}
				'nodeType' { return libjs.Value.from_i32(i32(actual.node_type_value())) }
				'textContent' {
					return if text := actual.text_content() {
						libjs.Value.from_string(vm.create_string_from_str(text))
					} else {
						libjs.js_null()
					}
				}
				'parentNode' {
					if parent := actual.parent() { return owner.wrap_node(parent) }
				}
				'parentElement' {
					if parent := actual.parent_element() {
						return owner.wrap_node(parent.as_node())
					}
				}
				'nextSibling' {
					if sibling := actual.next_sibling() { return owner.wrap_node(sibling) }
				}
				'nextElementSibling' {
					if sibling := actual.next_element_sibling() {
						return owner.wrap_node(sibling.as_node())
					}
				}
				'previousElementSibling' {
					if sibling := actual.previous_element_sibling() {
						return owner.wrap_node(sibling.as_node())
					}
				}
				'ownerDocument' {
					if !actual.is_document() { return owner.wrap_node(actual.document().as_node()) }
				}
				else {}
			}
			return libjs.js_null()
		}
		setter := if name == 'textContent' {
			libjs.NativeFunctionPointer(fn [host] (mut vm libjs.VM) !libjs.Value {
				mut actual := unsafe { &dom.Node(host.node(mut vm)!) }
				value := vm.argument(0)
				text := if value.is_nullish() {
					''
				} else {
					value.to_primitive_string(mut vm)!.str()
				}
				actual.set_text_content(text)!
				mut owner := unsafe { &Host(host) }
				owner.changed()
				return libjs.js_undefined()
			})
		} else {
			unsafe { nil }
		}
		host.accessor(mut node, name, getter, setter)
	}
	for name in ['id', 'className', 'href', 'innerHTML', 'outerHTML', 'tagName'] {
		host.accessor(mut element, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			actual := host.element(mut vm)!
			value := match name {
				'id' { actual.get_attribute_value('id') }
				'className' { actual.get_attribute_value('class') }
				'href' {
					if actual.has_attribute('href') {
						actual.as_node().document().encoding_parse_url(actual.get_attribute_value('href')) or { actual.as_node().document().url }.serialize()
					} else {
						''
					}
				}
				'innerHTML' { actual.inner_html()! }
				'outerHTML' { actual.outer_html()! }
				else { actual.node_name() }
			}
			return libjs.Value.from_string(vm.create_string_from_str(value))
		}, if name in ['id', 'className', 'href', 'innerHTML', 'outerHTML'] {
			libjs.NativeFunctionPointer(fn [host, name] (mut vm libjs.VM) !libjs.Value {
				mut actual := unsafe { &dom.Element(host.element(mut vm)!) }
				text := if name in ['innerHTML', 'outerHTML'] && vm.argument(0).is_null() {
					''
				} else {
					vm.argument(0).to_primitive_string(mut vm)!.str()
				}
				match name {
					'innerHTML' { actual.set_inner_html(text)! }
					'outerHTML' { actual.set_outer_html(text)! }
					else {
						actual.set_attribute_value(if name == 'className' { 'class' } else { name }, text)
					}
				}
				mut owner := unsafe { &Host(host) }
				owner.changed()
				return libjs.js_undefined()
			})
		} else {
			unsafe { nil }
		})
	}
	for name in ['getAttribute', 'setAttribute', 'removeAttribute', 'hasAttribute'] {
		host.method(mut element, name, if name == 'setAttribute' { 2 } else { 1 }, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut actual := unsafe { &dom.Element(host.element(mut vm)!) }
			key := vm.argument(0).to_primitive_string(mut vm)!.str()
			if name == 'hasAttribute' { return libjs.Value.from_bool(actual.has_attribute(key)) }
			if name == 'getAttribute' {
				return if actual.has_attribute(key) {
					libjs.Value.from_string(vm.create_string_from_str(actual.get_attribute_value(key)))
				} else {
					libjs.js_null()
				}
			}
			if name == 'setAttribute' {
				actual.set_attribute_value(key, vm.argument(1).to_primitive_string(mut vm)!.str())
			} else {
				actual.remove_attribute(key)
			}
			mut owner := unsafe { &Host(host) }
			owner.changed()
			return libjs.js_undefined()
		})
	}
	for name in ['getElementsByClassName', 'getElementsByTagName', 'querySelector'] {
		mut prototypes := [element, document]
		for mut prototype in prototypes {
			host.method(mut prototype, name, 1, fn [host, name] (mut vm libjs.VM) !libjs.Value {
				actual := host.node(mut vm)!
				if !actual.is_parent_node() {
					return vm.throw_error(.type_error, 'ParentNode method called on incompatible receiver')
				}
				key := vm.argument(0).to_primitive_string(mut vm)!.str()
				mut owner := unsafe { &Host(host) }
				if name == 'querySelector' {
					return if found := css.query_selector(actual, key) {
						owner.wrap_node(found.as_node())
					} else {
						libjs.js_null()
					}
				}

				mut parent := unsafe { &dom.ParentNode(actual) }
				collection := if name == 'getElementsByClassName' {
					parent.get_elements_by_class_name(key)
				} else {
					parent.get_elements_by_tag_name(key)
				}
				return owner.wrap_collection(collection)
			})
		}
	}
	host.method(mut document, 'getElementById', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		actual := host.node(mut vm)!
		if !actual.is_document() {
			return vm.throw_error(.type_error, 'getElementById requires a document')
		}
		id := vm.argument(0).to_primitive_string(mut vm)!.str()
		mut owner := unsafe { &Host(host) }
		return if found := actual.document().get_element_by_id(id) {
			owner.wrap_node(found.as_node())
		} else {
			libjs.js_null()
		}
	})
	host.method(mut document, 'createElement', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		actual := host.node(mut vm)!
		if !actual.is_document() {
			return vm.throw_error(.type_error, 'createElement requires a document')
		}
		element := actual.document().create_element(vm.argument(0).to_primitive_string(mut vm)!.str())!
		mut owner := unsafe { &Host(host) }
		return owner.wrap_node(element.as_node())
	})
	for name in ['body', 'head', 'currentScript', 'documentElement', 'URL', 'readyState'] {
		host.accessor(mut document, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			actual := host.node(mut vm)!
			if !actual.is_document() {
				return vm.throw_error(.type_error, 'Document property called on incompatible receiver')
			}
			mut owner := unsafe { &Host(host) }
			if name == 'URL' {
				return libjs.Value.from_string(vm.create_string_from_str(actual.document().url.serialize()))
			}
			if name == 'readyState' {
				return libjs.Value.from_string(vm.create_string_from_str(actual.document().ready_state().str()))
			}
			if name == 'body' {
				if body := actual.document().body() { return owner.wrap_node(body.as_node()) }
			} else if name == 'head' {
				if head := actual.document().head() { return owner.wrap_node(head.as_node()) }
			} else if name == 'currentScript' {
				if script := actual.document().current_script() { return owner.wrap_node(script.as_node()) }
			} else {
				if root := actual.document().document_element() {
					return owner.wrap_node(root.as_node())
				}
			}
			return libjs.js_null()
		}, unsafe { nil })
	}
	for name in ['appendChild', 'removeChild'] {
		host.method(mut node, name, 1, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut actual := unsafe { &dom.Node(host.node(mut vm)!) }
			value := vm.argument(0)
			if !value.is_object() { return vm.throw_error(.type_error, 'Node argument required') }
			child := host.nodes[voidptr(value.as_object())] or { return vm.throw_error(.type_error, 'Node argument required') }
			if name == 'appendChild' {
				actual.append_child(child)!
			} else {
				actual.remove_child(child)!
			}
			mut owner := unsafe { &Host(host) }
			owner.changed()
			return value
		})
	}
	host.install_events(mut node)!
}

@[heap]
struct Collection {
	host       &Host
	collection &dom.HTMLCollection
}

fn (collection &Collection) get_own_property(key libjs.PropertyName) ?libjs.PropertyDescriptor {
	if collection.host.closed { return none }
	mut host := unsafe { &Host(collection.host) }
	if key.is_number() {
		if element := collection.collection.item(int(key.number)) {
			return libjs.PropertyDescriptor{ value: host.wrap_node(element.as_node()), writable: false, enumerable: true, configurable: false }
		}
	}
	return none
}

fn (collection &Collection) own_property_keys() []libjs.PropertyName {
	if collection.host.closed { return [] }
	return []libjs.PropertyName{len: collection.collection.length(), init: libjs.PropertyName.from_number(u32(index))}
}

fn (mut host Host) wrap_collection(collection &dom.HTMLCollection) libjs.Value {
	mut object := libjs.Object.create(host.realm, host.collection_prototype)
	object.class_name = 'HTMLCollection'
	object.host_properties = libjs.HostProperties(&Collection{ host: host, collection: collection })
	return libjs.Value.from_object(object)
}

fn (host &Host) collection_receiver(mut vm libjs.VM) !&dom.HTMLCollection {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if provider := vm.this_value().as_object().host_properties {
			if provider is Collection {
				if voidptr(provider.host) == voidptr(host) { return provider.collection }
			}
		}
	}
	return vm.throw_error(.type_error, 'HTMLCollection method called on incompatible receiver')
}
