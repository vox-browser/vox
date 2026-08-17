@[has_globals]
module html

import dom

__global html_agent_test_goal_reached bool

fn html_agent_test_reach_goal() {
	html_agent_test_goal_reached = true
}

fn html_agent_test_goal() bool {
	return html_agent_test_goal_reached
}

fn test_worker_agent_owns_worker_event_loop_and_spins() {
	unsafe {
		html_agent_test_goal_reached = false
	}
	mut agent := WorkerAgent.create(.yes)
	assert agent.can_block == .yes
	assert agent.event_loop.type_ == .worker
	queue_a_task(.javascript_engine, agent.event_loop, none, html_agent_test_reach_goal)
	agent.spin_event_loop_until(html_agent_test_goal)
	assert html_agent_test_goal_reached
}

fn test_similar_origin_window_agent_and_reaction_stack() {
	mut agent := SimilarOriginWindowAgent.create()
	assert agent.can_block == .no
	assert agent.event_loop.type_ == .window
	assert !agent.mutation_observer_microtask_queued
	mut document := &dom.Document{}
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'x-widget')!
	agent.custom_element_reactions_stack.push_element_queue()
	agent.custom_element_reactions_stack.enqueue_in_current_element_queue(element)!
	assert agent.custom_element_reactions_stack.current_element_queue()!.len == 1
	assert agent.custom_element_reactions_stack.pop_element_queue()![0] == element
	assert agent.custom_element_reactions_stack.element_queue_stack.len == 0
	assert relevant_similar_origin_window_agent().event_loop.type_ == .window
	assert relevant_agent().event_loop.type_ == .window
}
