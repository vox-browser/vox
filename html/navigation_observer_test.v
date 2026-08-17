@[has_globals]
module html

import dom

__global (
	navigation_observer_complete_calls = 0
	navigation_observer_changed_calls  = 0
)

fn navigation_observer_complete_callback() {
	navigation_observer_complete_calls++
}

fn navigation_observer_changed_callback() {
	navigation_observer_changed_calls++
}

fn test_navigation_observer_registers_notifies_and_unregisters() {
	navigation_observer_complete_calls = 0
	navigation_observer_changed_calls = 0
	navigable := &dom.Navigable{}
	mut observer := NavigationObserver.create(navigable)
	observer.set_navigation_complete(navigation_observer_complete_callback)
	observer.set_ongoing_navigation_changed(navigation_observer_changed_callback)
	notify_navigation_complete(navigable)
	notify_ongoing_navigation_changed(navigable)
	assert navigation_observer_complete_calls == 1
	assert navigation_observer_changed_calls == 1
	observer.finalize()
	notify_navigation_complete(navigable)
	assert navigation_observer_complete_calls == 1
}

fn test_browsing_context_group_creation_and_membership() {
	before := user_agent_browsing_context_group_count()
	page := &dom.Page{}
	created := BrowsingContextGroup.create_a_new_browsing_context_group_and_document(page) or {
		panic(err)
	}
	mut group := created.browsing_context_group
	assert user_agent_browsing_context_group_count() == before + 1
	assert group.page() == page
	assert group.browsing_context_set().len == 1
	context := group.browsing_context_set()[0]
	assert context.active_document() or { panic('missing document') } == created.document
	assert context.group_handle == voidptr(group)
	group.append(context)
	assert group.browsing_context_set().len == 1
	group.finalize()
	assert user_agent_browsing_context_group_count() == before
}
