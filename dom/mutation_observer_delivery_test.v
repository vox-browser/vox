module dom

import platform

@[heap]
struct MutationDeliveryLog {
mut:
	queued int
	deliveries []int
}

fn test_mutation_observer_host_queue_batches_across_documents_and_take_records() {
	mut first_document := Document.create(url_about_blank())
	mut second_document := Document.create(url_about_blank())
	defer { first_document.finalize(); second_document.finalize() }
	mut first := first_document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut second := second_document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	first_document.append_child(first)
	second_document.append_child(second)
	mut log := &MutationDeliveryLog{}
	mut queue := MutationObserverDeliveryQueue.create(fn [mut log] () { log.queued++ })
	mut observer := MutationObserver.construct_impl(&CallbackType{
		mutation_callback: fn [mut log] (records []&MutationRecord, _ &MutationObserver) { log.deliveries << records.len }
	})!
	observer.delivery_queue_ = queue
	mut first_options := MutationObserverOptions{attributes:true}
	mut second_options := MutationObserverOptions{attributes:true}
	observer.observe(first.as_node(), mut first_options)!
	observer.observe(second.as_node(), mut second_options)!
	first.set_attribute_value('data-first', '1')
	second.set_attribute_value('data-second', '2')
	assert log.queued == 1
	assert log.deliveries.len == 0
	queue.notify()
	assert log.deliveries == [2]
	first.set_attribute_value('data-first', '3')
	assert observer.take_records().len == 1
	queue.notify()
	assert log.deliveries == [2]
	observer.disconnect()
	queue.retire()
}

fn test_mutation_observer_queue_keeps_removed_subtree_transients_until_notification() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	document.append_child(parent)
	parent.append_child(child)
	mut queue := MutationObserverDeliveryQueue.create(fn () {})
	mut observer := MutationObserver.construct_impl(none)!
	observer.delivery_queue_ = queue
	mut options := MutationObserverOptions{subtree:true,child_list:true,attributes:true}
	observer.observe(parent.as_node(), mut options)!
	child.remove(false)
	child.set_attribute_value('data-removed', '1')
	assert observer.record_queue.len == 2
	queue.notify()
	assert observer.record_queue.len == 0
	child.set_attribute_value('data-removed', '2')
	assert observer.record_queue.len == 0
	observer.disconnect()
	queue.retire()
}

fn test_reobservation_removes_only_transients_from_the_same_registration() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section')!
	mut a := document.create_element_ns('http://www.w3.org/1999/xhtml', 'a')!
	mut b := document.create_element_ns('http://www.w3.org/1999/xhtml', 'b')!
	first.append_child(a)
	second.append_child(b)
	mut queue := MutationObserverDeliveryQueue.create(fn () {})
	mut observer := MutationObserver.construct_impl(none)!
	observer.delivery_queue_ = queue
	mut options := MutationObserverOptions{subtree:true,child_list:true,attributes:true}
	observer.observe(first.as_node(), mut options)!
	observer.observe(second.as_node(), mut options)!
	a.remove(false)
	b.remove(false)
	observer.observe(first.as_node(), mut options)!
	observer.take_records()
	a.set_attribute_value('title', 'unobserved')
	b.set_attribute_value('title', 'observed')
	assert observer.record_queue.len == 1
	assert voidptr(observer.record_queue[0].target) == voidptr(b)
	observer.disconnect()
	b.set_attribute_value('title', 'disconnected')
	assert observer.record_queue.len == 0
	queue.retire()
}

fn test_deferred_mutation_records_own_metadata_outside_native_request_scratch() {
	mut document := Document.create(url_about_blank())
	document.enable_native_storage()
	defer { document.finalize() }
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut observer := MutationObserver.construct_impl(none)!
	mut queue := MutationObserverDeliveryQueue.create(fn () {})
	observer.delivery_queue_ = queue
	mut options := MutationObserverOptions{attributes:true,attribute_old_value:true}
	observer.observe(target.as_node(), mut options)!
	mut scratch := platform.begin_thread_scratch('native mutation record lifetime')
	mut node := target.as_node()
	node.queue_mutation_record(.attributes, 'data-native'.clone(), 'urn:native'.clone(), 'old native text'.clone(), []&Node{}, []&Node{}, unsafe { nil }, unsafe { nil })
	scratch.finish()
	assert observer.record_queue.len == 1
	record := observer.record_queue[0]
	assert (record.attribute_name_() or { '' }) == 'data-native'
	assert (record.attribute_namespace_() or { '' }) == 'urn:native'
	assert (record.old_value_() or { '' }) == 'old native text'
	observer.disconnect()
	queue.retire()
}

fn test_mutation_delivery_uses_creation_order_when_mutations_arrive_in_reverse() {
    mut document:=Document.create(url_about_blank())
    defer { document.finalize() }
    mut first_target:=document.create_element_ns('http://www.w3.org/1999/xhtml','div')!
    mut second_target:=document.create_element_ns('http://www.w3.org/1999/xhtml','div')!
    document.append_child(first_target);document.append_child(second_target)
    mut log:=&MutationDeliveryLog{}
    mut queue:=MutationObserverDeliveryQueue.create(fn () {})
    mut first:=MutationObserver.construct_impl(&CallbackType{mutation_callback:fn [mut log] (_ []&MutationRecord,_ &MutationObserver) { log.deliveries<<1 }})!
    mut second:=MutationObserver.construct_impl(&CallbackType{mutation_callback:fn [mut log] (_ []&MutationRecord,_ &MutationObserver) { log.deliveries<<2 }})!
    first.delivery_queue_=queue;second.delivery_queue_=queue
    mut first_options:=MutationObserverOptions{attributes:true};mut second_options:=MutationObserverOptions{attributes:true}
    first.observe(first_target.as_node(),mut first_options)!;second.observe(second_target.as_node(),mut second_options)!
    second_target.set_attribute_value('data-order','second');first_target.set_attribute_value('data-order','first')
    assert log.deliveries.len==0
    queue.notify()
    assert log.deliveries==[1,2]
    first.disconnect();second.disconnect();queue.retire()
}
