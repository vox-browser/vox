// Live host boundaries for ViewTransition.cpp's old/new capture traversals.
module dom

import viewtransition
import webidl

struct ViewTransitionElementCollector {
mut:
	elements []&viewtransition.TransitionElement
	previous map[voidptr]&viewtransition.TransitionElement
	names    map[string]bool
}

fn view_transition_snapshot_size(target voidptr) (f64, f64) {
	document := unsafe { &Document(target) }
	viewport := document.viewport_rect()
	return viewport.width, viewport.height
}

fn view_transition_capture_image(target voidptr) ?&viewtransition.ImageFrame {
	element := unsafe { &Element(target) }
	return &viewtransition.ImageFrame{
		handle: voidptr(element.capture_the_image())
	}
}

fn view_transition_set_captured(target voidptr, value bool) {
	mut element := unsafe { &Element(target) }
	element.set_captured_in_a_view_transition(value)
}

fn view_transition_state_changed(target voidptr) {
	document := unsafe { &Document(target) }
	if transition := document.get_active_view_transition() {
		transition.sync_document_state()
	}
}

pub fn (mut document Document) set_view_transition_promise_context(context webidl.PromiseContext) {
	document.set_relevant_realm_promise_context(context)
}

fn view_transition_refresh_elements(target voidptr, mut context viewtransition.TransitionDocument, capturing_old bool) {
	mut document := unsafe { &Document(target) }
	document.update_layout(.view_transition_capture)
	view_transition_synchronize_style_sheet(document, mut context)
	collector := &ViewTransitionElementCollector{}
	mut mutable_collector := unsafe { &ViewTransitionElementCollector(collector) }
	for item in context.elements {
		mutable_collector.previous[item.target] = item
		mut mutable_item := unsafe { &viewtransition.TransitionElement(item) }
		mutable_item.rendered = false
	}
	if root := document.document_element() {
		root.as_node().visit_inclusive_subtree(fn [document, root, collector, capturing_old] (node &Node) TraversalDecision {
			mut element := node.as_element() or { return .@continue }
			if voidptr(node.document()) != voidptr(document) || !node.is_connected() {
				return .@continue
			}
			if element.not_rendered() { return .@continue }
			name := element.document_scoped_view_transition_name() or { return .@continue }
			styled_node := element.el_layout_node() or { return .@continue }
			layout_node := styled_node.layout_node_ or { return .@continue }
			mut record := collector.previous[voidptr(element)] or {
				&viewtransition.TransitionElement{
					id:                     node.unique_id().value().str()
					target:                 voidptr(element)
					capture_image_callback: view_transition_capture_image
					set_captured_callback:  view_transition_set_captured
				}
			}
			record.view_transition_name = name
			record.rendered = true
			record.is_document_element = voidptr(element) == voidptr(root)
			record.width = layout_node.border_box_.width
			record.height = layout_node.border_box_.height
			if layout_node.bridge_callbacks().view_transition_properties_callback != unsafe { nil } {
				properties :=
					layout_node.bridge_callbacks().view_transition_properties_callback(layout_node.layout_handle)
				record.writing_mode = properties['writing-mode']
				record.direction = properties['direction']
				record.mix_blend_mode = properties['mix-blend-mode']
				record.backdrop_filter = properties['backdrop-filter']
				record.color_scheme = properties['color-scheme']
			}
			mut collector_mut := unsafe { &ViewTransitionElementCollector(collector) }
			collector_mut.elements << record
			// Preserve the source's duplicate boundary: the duplicate itself is
			// not marked, and the model clears the previously marked elements.
			if collector.names[name] { return .@break }
			collector_mut.names[name] = true
			if capturing_old { element.set_captured_in_a_view_transition(true) }
			if element.skips_its_contents() { return .skip_children_and_continue }
			return .@continue
		})
	}
	context.elements = collector.elements
}

fn view_transition_synchronize_style_sheet(document &Document, mut context viewtransition.TransitionDocument) {
	if sheet := document.document_dynamic_view_transition_style_sheet() {
		context.style_sheet_target = sheet.css_handle
		context.insert_rule_callback = sheet.insert_view_transition_rule_callback
		context.remove_rule_callback = sheet.remove_view_transition_rule_callback
		context.set_selector_callback = sheet.set_view_transition_selector_callback
	}
}

fn (mut document Document) ensure_view_transition_document() &viewtransition.TransitionDocument {
	if document.view_transition_document_ == unsafe { nil } {
		document.view_transition_document_ = &viewtransition.TransitionDocument{
			target:                    voidptr(&document)
			snapshot_size_callback:    view_transition_snapshot_size
			refresh_elements_callback: view_transition_refresh_elements
			promise_context:           document.view_transition_promise_context_
			state_changed_callback:    view_transition_state_changed
		}
	}
	mut context := document.view_transition_document_
	view_transition_synchronize_style_sheet(&document, mut context)
	return document.view_transition_document_
}

// Setup, skip and their callback flushes use the owning document's actual
// DOM-manipulation task queue. DOM-only fixtures have no HTML event-loop hook.
fn (transition &ViewTransition) queue_pending_dom_tasks() bool {
	document := transition.document_
	if document == unsafe { nil } { return false }
	hook := document.lifecycle_hook_ or { return false }
	if hook.queue_an_element_task == unsafe { nil } { return false }
	root := document.document_element() or { return false }
	if transition.dom_task_pending_ || transition.transition_document_.dom_tasks.len == 0 {
		return true
	}
	mut mutable_transition := unsafe { &ViewTransition(transition) }
	mutable_transition.dom_task_pending_ = true
	root.queue_an_element_task(.dom_manipulation, fn [transition] () {
		mut mutable := unsafe { &ViewTransition(transition) }
		mutable.dom_task_pending_ = false
		mut context := mutable.transition_document_
		context.run_next_dom_task()
		mutable.sync_document_state()
		mutable.queue_pending_dom_tasks()
	})
	return true
}

fn queue_view_transition_document_task(document &Document, steps fn ()) bool {
	hook := document.lifecycle_hook_ or { return false }
	if hook.queue_an_element_task == unsafe { nil } { return false }
	root := document.document_element() or { return false }
	root.queue_an_element_task(.dom_manipulation, steps)
	return true
}

fn (transition &ViewTransition) skip_with_reason(reason webidl.Value) {
	if transition.transition_ == unsafe { nil } { return }
	mut inner := transition.transition_
	inner.skip_the_view_transition(reason)
	mut context := transition.transition_document_
	if !transition.queue_pending_dom_tasks() { context.drain_dom_tasks() }
	transition.sync_document_state()
}

pub fn (transition &ViewTransition) captured_element(name string) ?&viewtransition.CapturedElement {
	if transition.transition_ == unsafe { nil } { return none }
	return transition.transition_.named_elements[name] or { none }
}

pub fn (transition &ViewTransition) ready() &webidl.Promise {
	return transition.transition_.ready()
}

pub fn (transition &ViewTransition) update_callback_done() &webidl.Promise {
	return transition.transition_.update_callback_done()
}

pub fn (transition &ViewTransition) finished() &webidl.Promise {
	return transition.transition_.finished()
}

pub fn (transition &ViewTransition) transition_root_pseudo_element() &PseudoElementTreeNode_ {
	return transition.transition_root_pseudo_element_
}

pub fn (transition &ViewTransition) update_pseudo_element_styles() ! {
	if transition.transition_ == unsafe { nil } { return }
	mut context := transition.transition_document_
	context.refresh_live_elements(false)
	mut inner := transition.transition_
	inner.update_pseudo_element_styles()!
	transition.sync_document_state()
}

fn (transition &ViewTransition) sync_transition_pseudo_tree() {
	if transition.transition_ == unsafe { nil }
		|| transition.transition_root_pseudo_element_ == unsafe { nil } {
		return
	}
	mut mutable_transition := unsafe { &ViewTransition(transition) }
	if transition.transition_pseudo_nodes_.len == 0 {
		for index, pseudo in transition.transition_.pseudo_elements {
			parent := if parent_index := pseudo.parent_index {
				assert parent_index < index
				transition.transition_pseudo_nodes_[parent_index]
			} else {
				transition.transition_root_pseudo_element_
			}
			node := &PseudoElementTreeNode_{
				parent_:               parent
				view_transition_type_: match pseudo.type_ {
					.group { PseudoElement.view_transition_group }
					.image_pair { PseudoElement.view_transition_image_pair }
					.old { PseudoElement.view_transition_old }
					.new_ { PseudoElement.view_transition_new }
				}
				view_transition_name_: pseudo.view_transition_name
			}
			mut mutable_parent := unsafe { &PseudoElementTreeNode_(parent) }
			mutable_parent.children_ << node
			mutable_transition.transition_pseudo_nodes_ << node
		}
	}
	for index, pseudo in transition.transition_.pseudo_elements {
		mut node := transition.transition_pseudo_nodes_[index]
		if frame := pseudo.content {
			if frame.handle != unsafe { nil } {
				node.replaced_content_ = unsafe { &DecodedImageFrame_(frame.handle) }
			}
		}
	}
}
