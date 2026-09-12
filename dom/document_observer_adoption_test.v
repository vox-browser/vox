module dom

struct DocumentObserverAdoptionObservation {
mut:
	became_active   int
	became_inactive int
}

fn test_document_observer_retarget_for_adoption_tracks_activity_transitions() {
	mut inactive_document := Document.create(url_about_blank())
	mut active_document := Document.create(url_about_blank())
	mut navigable := &Navigable{
		active_document_: active_document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	active_document.set_cached_navigable(navigable)
	assert !inactive_document.is_fully_active()
	assert active_document.is_fully_active()

	observation := &DocumentObserverAdoptionObservation{}
	mut observer := DocumentObserver.create(mut inactive_document)
	observer.set_document_became_active(fn [observation] () {
		mut result := unsafe { &DocumentObserverAdoptionObservation(observation) }
		result.became_active++
	})
	observer.set_document_became_inactive(fn [observation] () {
		mut result := unsafe { &DocumentObserverAdoptionObservation(observation) }
		result.became_inactive++
	})

	observer.retarget_for_adoption(mut active_document)
	assert observer.document()? == active_document
	assert observer !in inactive_document.document_observers
	assert observer in active_document.document_observers
	assert observation.became_active == 1
	assert observation.became_inactive == 0

	observer.retarget_for_adoption(mut inactive_document)
	assert observer.document()? == inactive_document
	assert observer in inactive_document.document_observers
	assert observer !in active_document.document_observers
	assert observation.became_active == 1
	assert observation.became_inactive == 1

	// Retargeting without an activity-state change does not synthesize one.
	mut another_inactive_document := Document.create(url_about_blank())
	observer.retarget_for_adoption(mut another_inactive_document)
	assert observation.became_active == 1
	assert observation.became_inactive == 1
	observer.finalize()
}
