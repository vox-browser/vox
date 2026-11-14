module browserjs

import dom

pub type NodeEventTargetLookup = fn (key string) ?&dom.Node

pub type NodeEventTargetState = fn (node &dom.Node) ?string

@[heap]
struct NodeEventTargetResolver {
mut:
	function voidptr
	closed   bool
}

// Compact node facades share their native node's listener list. The resolver
// also covers elements added by the parser after ElementWheelHost took its
// initial registry snapshot.
pub fn (mut runtime Runtime) install_node_event_target_binding(lookup NodeEventTargetLookup, state NodeEventTargetState) ! {
	runtime.event_binding()!
	owner := voidptr(&runtime)
	mut resolver := &NodeEventTargetResolver{}
	runtime.define_value_host_function('__ladybirdBindNodeEventTarget', fn [owner, lookup] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len != 2 || !C.JSValueIsObject(runtime.context, args[0]) {
			return runtime.event_binding_type_error('Invalid node EventTarget binding')
		}
		key := runtime.binding_dom_string(args[1])!
		node := lookup(key) or {
			return runtime.event_binding_type_error('Node wrapper has no native owner')
		}
		if node.is_element() || node.is_document() {
			return runtime.event_binding_type_error('Elements and documents keep their own EventTarget binding')
		}
		target := unsafe { &dom.EventTarget(node) }
		binding := runtime.event_binding()!
		if existing := binding.targets[args[0]] {
			return C.vox_jsc_JSValueMakeBoolean(runtime.context, voidptr(existing) == voidptr(target))
		}
		// A node whose generic wrapper predates its facade keeps that owner.
		if voidptr(target) in binding.target_wrappers {
			return C.vox_jsc_JSValueMakeBoolean(runtime.context, false)
		}
		runtime.bind_event_target(args[0], target)!
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, true)
	})!
	runtime.define_value_host_function('__ladybirdNodeEventTargetSetResolver', fn [owner, mut resolver] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len != 1 || !C.JSValueIsObject(runtime.context, args[0])
			|| !C.JSObjectIsFunction(runtime.context, args[0]) {
			return runtime.event_binding_type_error('Node wrapper resolver must be callable')
		}
		if resolver.function != unsafe { nil } {
			return runtime.event_binding_type_error('Node wrapper resolver is already installed')
		}
		resolver.function = runtime.retain_javascript_value(args[0])!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	runtime.install_event_target_wrapper_provider(EventTargetWrapperProvider{
		owner:  voidptr(resolver)
		create: fn [owner, resolver, state] (target &dom.EventTarget) !voidptr {
			if resolver.closed || resolver.function == unsafe { nil } || target.data.kind != .node {
				return unsafe { nil }
			}
			node := unsafe { &dom.Node(target) }
			if node.is_document() { return unsafe { nil } }
			// Materialize a late element's bridge key and facade before the
			// EventTarget fallback can cache a generic wrapper for that owner.
			// Otherwise a later selector creates a second wrapper and throws.
			encoded := state(node) or { return unsafe { nil } }
			mut runtime := unsafe { &Runtime(owner) }
			wrapper := runtime.call_javascript_function(resolver.function,
				C.vox_jsc_JSValueMakeUndefined(runtime.context), [runtime.binding_string(encoded)])!
			if !C.JSValueIsObject(runtime.context, wrapper) { return unsafe { nil } }
			return wrapper
		}
	})!
	runtime.add_close_handler(fn [mut resolver] () {
		resolver.closed = true
		resolver.function = unsafe { nil }
	})
}
