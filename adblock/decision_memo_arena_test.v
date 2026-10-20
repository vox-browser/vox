module adblock

import platform

fn test_decision_memo_owns_keys_and_results_after_document_storage_retires() {
	key := 'document arena memo fixture'
	mut arena := platform.new_arena('decision source')
	entry := arena.enter()
	retain_filter_decision(key.clone(), 'retained decision'.clone())
	arena.leave(entry)
	arena.release()
	assert retained_filter_decision(key)? == 'retained decision'
	filter_decision_memo_.delete(key)
}
