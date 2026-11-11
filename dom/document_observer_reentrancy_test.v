module dom

@[heap]
struct DocumentObserverReentryLog {
mut:
	nested bool
	events []string
}

fn test_document_observer_notifications_keep_a_snapshot_per_invocation() {
	mut document := Document.create(url_about_blank())
	mut first := DocumentObserver.create(mut document)
	mut second := DocumentObserver.create(mut document)
	mut log := &DocumentObserverReentryLog{}
	second.set_document_readiness_observer(fn [mut log] (_ DocumentReadyState) {
		log.events << 'outer second'
	})
	first.set_document_readiness_observer(fn [mut document, mut second, mut log] (_ DocumentReadyState) {
		if log.nested {
			log.events << 'nested first'
			return
		}
		log.events << 'outer first'
		second.finalize()
		mut added := DocumentObserver.create(mut document)
		added.set_document_readiness_observer(fn [mut log] (_ DocumentReadyState) {
			log.events << 'nested added'
		})
		log.nested = true
		document.notify_each_document_observer_readiness()
		log.nested = false
	})
	document.notify_each_document_observer_readiness()
	assert log.events == ['outer first', 'nested first', 'nested added', 'outer second']
}
