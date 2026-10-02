module streams

@[heap]
struct TransformWrapperPreparationObservation {
mut:
	readable voidptr
	writable voidptr
	order []string
}

fn test_transform_prepares_actual_native_component_wrappers_before_start_callback() {
	observation := &TransformWrapperPreparationObservation{}
	realm := StreamRealm.create(55).with_transform_wrapper_preparer(fn [observation] (stream &TransformStream) {
		mut state := unsafe { &TransformWrapperPreparationObservation(observation) }
		assert !stream.wrappers_are_prepared()
		readable_controller := stream.readable().default_controller() or { panic('missing initialized native readable controller') }
		assert !readable_controller.started()
		assert !stream.writable().controller().started()
		state.readable = voidptr(stream.readable())
		state.writable = voidptr(stream.writable())
		state.order << 'wrap readable and writable'
	})
	stream := TransformStream.create_for_constructor(realm, Transformer{
		start: fn [observation] () ! {
			mut state := unsafe { &TransformWrapperPreparationObservation(observation) }
			assert state.readable != unsafe { nil } && state.writable != unsafe { nil }
			state.order << 'start'
		}
	}, QueuingStrategy{}, QueuingStrategy{})!
	assert stream.wrappers_are_prepared()
	assert observation.readable == voidptr(stream.readable())
	assert observation.writable == voidptr(stream.writable())
	assert observation.order == ['wrap readable and writable', 'start']
}

