module dom

fn test_native_attribute_keeps_identity_and_document_through_adoption_and_detachment() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	defer {
		source.finalize()
		destination.finalize()
	}
	mut element := source.create_element('div')!
	element.set_attribute_value('data-value', 'first')
	attribute := element.get_attribute_node('data-value')?
	assert voidptr(attribute.document()) == voidptr(source)
	destination.adopt_node(element.as_node())
	element.remove_attribute('data-value')
	assert attribute.owner_element() == none
	assert voidptr(attribute.document()) == voidptr(destination)
	element.set_attribute_value('data-value', 'replacement')
	replacement := element.get_attribute_node('data-value')?
	assert voidptr(replacement) != voidptr(attribute)
	assert attribute.value() == 'first'
	mut attributes := element.attributes()
	assert voidptr(attributes.set_attribute(attribute)!) == voidptr(replacement)
	assert voidptr(element.get_attribute_node('data-value')?) == voidptr(attribute)
	assert replacement.owner_element() == none
	assert voidptr(replacement.document()) == voidptr(destination)
}

fn test_native_attribute_attachment_keeps_source_storage_until_destination_retires() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	source.enable_native_storage()
	destination.enable_native_storage()
	source_storage := source.native_storage()
	destination_storage := destination.native_storage()
	mut source_scope := source.enter_native_storage()
	mut original := source.create_element('div')!
	original.set_attribute_value('data-value', 'retained native attribute payload'.clone())
	attribute := original.get_attribute_node('data-value')?
	original.remove_attribute('data-value')
	source_scope.finish()
	mut destination_scope := destination.enter_native_storage()
	mut element := destination.create_element('div')!
	_ = element.set_attribute_node_for_bindings(attribute)!
	destination_scope.finish()
	source.finalize()
	source.release_native_storage()
	assert element.get_attribute_value('data-value') == 'retained native attribute payload'
	assert voidptr(element.get_attribute_node('data-value')?) == voidptr(attribute)
	assert voidptr(attribute.document()) == voidptr(destination)
	destination.finalize()
	destination.release_native_storage()
	$if prealloc {
		assert source_storage.arena.usage().used == 0
		assert destination_storage.arena.usage().used == 0
	}
}

fn test_native_qualified_attribute_set_preserves_first_matching_namespace_and_validation() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div')!
	element.set_attribute_ns_for_bindings('urn:first', 'data-value', 'foreign')!
	element.set_attribute_value('data-value', 'ordinary')
	foreign := element.get_attribute_node_ns('urn:first', 'data-value')?
	ordinary := element.get_attribute_node_ns(none, 'data-value')?
	element.set_attribute_for_bindings('data-value', 'updated')!
	assert foreign.value() == 'updated'
	assert ordinary.value() == 'ordinary'
	assert voidptr(element.get_attribute_node('data-value')?) == voidptr(foreign)
	for name in ['', 'bad name', 'bad/name', 'bad=name'] {
		mut failed := false
		_ = element.toggle_attribute(name, false) or {
			failed = err.msg().starts_with('InvalidCharacterError:')
			false
		}
		assert failed
	}
}

fn test_detached_attribute_attachment_uses_allocation_owner_after_source_document_retires() {
	mut source := Document.create(url_about_blank())
	mut realm := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	source.enable_native_storage()
	realm.enable_native_storage()
	destination.enable_native_storage()
	source_storage := source.native_storage()
	realm_storage := realm.native_storage()
	destination_storage := destination.native_storage()
	mut source_scope := source.enter_native_storage()
	mut original := source.create_element('div')!
	original.set_attribute_value('data-value', 'detached payload after retirement'.clone())
	attribute := original.get_attribute_node('data-value')?
	original.remove_attribute('data-value')
	source_scope.finish()
	// A realm's native wrapper registry keeps this allocation lifetime alive.
	realm.share_native_storage_lifetime(attribute.storage_owner())
	source.finalize()
	source.release_native_storage()
	assert source.native_storage() == unsafe { nil }
	mut destination_scope := destination.enter_native_storage()
	mut target := destination.create_element('div')!
	_ = target.set_attribute_node_for_bindings(attribute)!
	destination_scope.finish()
	assert voidptr(attribute.storage_owner()) == voidptr(source_storage)
	realm.finalize()
	realm.release_native_storage()
	assert target.get_attribute_value('data-value') == 'detached payload after retirement'
	assert voidptr(attribute.document()) == voidptr(destination)
	destination.finalize()
	destination.release_native_storage()
	$if prealloc {
		assert source_storage.arena.usage().used == 0
		assert realm_storage.arena.usage().used == 0
		assert destination_storage.arena.usage().used == 0
	}
}
