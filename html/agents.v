// Copyright (c) 2025, Shannon Booth <shannon@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Scripting/{Agent,WorkerAgent,SimilarOriginWindowAgent} and
// CustomElements/CustomElementReactionsStack.
@[has_globals]
module html

import dom

pub enum AgentType {
	similar_origin_window
	dedicated_worker
	shared_worker
	service_worker
	worklet
}

pub enum CanBlock {
	no
	yes
}

@[heap]
pub struct Agent {
pub:
	can_block CanBlock
pub mut:
	event_loop &EventLoop = unsafe { nil }
}

pub fn (mut agent Agent) spin_event_loop_until(goal_condition fn () bool) {
	agent.event_loop.spin_until(goal_condition)
}

@[heap]
pub struct WorkerAgent {
	Agent
}

pub fn WorkerAgent.create(can_block CanBlock) &WorkerAgent {
	return &WorkerAgent{
		Agent: Agent{
			can_block:  can_block
			event_loop: EventLoop.create(.worker)
		}
	}
}

pub struct CustomElementReactionsStack {
pub mut:
	element_queue_stack                 [][]&dom.Element
	backup_element_queue                []&dom.Element
	processing_the_backup_element_queue bool
}

pub fn (mut stack CustomElementReactionsStack) push_element_queue() {
	stack.element_queue_stack << []&dom.Element{}
}

pub fn (mut stack CustomElementReactionsStack) pop_element_queue() ![]&dom.Element {
	if stack.element_queue_stack.len == 0 {
		return error('custom element reactions stack is empty')
	}
	queue := stack.element_queue_stack.last().clone()
	stack.element_queue_stack.delete_last()
	return queue
}

pub fn (stack &CustomElementReactionsStack) current_element_queue() ![]&dom.Element {
	if stack.element_queue_stack.len == 0 {
		return error('custom element reactions stack is empty')
	}
	return stack.element_queue_stack.last().clone()
}

pub fn (mut stack CustomElementReactionsStack) enqueue_in_current_element_queue(element &dom.Element) ! {
	if stack.element_queue_stack.len == 0 {
		return error('custom element reactions stack is empty')
	}
	stack.element_queue_stack[stack.element_queue_stack.len - 1] << element
}

@[heap]
pub struct SimilarOriginWindowAgent {
	Agent
pub mut:
	mutation_observer_microtask_queued bool
	pending_mutation_observers         []&dom.MutationObserver
	custom_element_reactions_stack     CustomElementReactionsStack
	signal_slots                       []&dom.HTMLSlotElement
}

pub fn SimilarOriginWindowAgent.create() &SimilarOriginWindowAgent {
	return &SimilarOriginWindowAgent{
		Agent: Agent{
			can_block:  .no
			event_loop: EventLoop.create(.window)
		}
	}
}

pub fn (agent &SimilarOriginWindowAgent) current_element_queue() ![]&dom.Element {
	return agent.custom_element_reactions_stack.current_element_queue()
}

__global html_relevant_similar_origin_window_agent &SimilarOriginWindowAgent

// A JS object selects the VM agent upstream. The V runtime currently has one
// main-thread realm, so this is its relevant agent.
pub fn relevant_similar_origin_window_agent() &SimilarOriginWindowAgent {
	if html_relevant_similar_origin_window_agent == unsafe { nil } {
		html_relevant_similar_origin_window_agent = SimilarOriginWindowAgent.create()
	}
	return html_relevant_similar_origin_window_agent
}

pub fn relevant_agent() &Agent {
	return unsafe { &Agent(relevant_similar_origin_window_agent()) }
}
