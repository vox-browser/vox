module browserjs

import dom

// Realms of one agent share a JSC context group, so script can pass a node
// wrapper from one realm (an iframe's document, say) to another realm's DOM
// methods. Each realm keeps its own wrappers; this finds the native node of
// a wrapper owned by another realm in the same group.
pub fn (runtime &Runtime) foreign_event_target(wrapper voidptr) ?&dom.EventTarget {
	if runtime.context == unsafe { nil } || !C.JSValueIsObject(runtime.context, wrapper) {
		return none
	}
	group := C.JSContextGetGroup(runtime.context)
	for owner, binding in event_target_bindings_ {
		if owner == voidptr(runtime) {
			continue
		}
		other := unsafe { &Runtime(owner) }
		if other.closed || other.context == unsafe { nil } || C.JSContextGetGroup(other.context) != group {
			continue
		}
		if target := binding.targets[wrapper] {
			return target
		}
	}
	return none
}

// __ladybirdForeignNodeState(value) returns `state` of the native node behind
// another realm's node wrapper, or null for anything else.
pub fn (mut runtime Runtime) install_foreign_node_lookup(state fn (&dom.Node) string) ! {
	owner := voidptr(&runtime)
	runtime.own_closure(voidptr(state))
	runtime.define_value_host_function('__ladybirdForeignNodeState', fn [owner, state] (_ voidptr, args []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		if args.len == 0 {
			return C.vox_jsc_JSValueMakeNull(runtime.context)
		}
		target := runtime.foreign_event_target(args[0]) or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
		if target.data.kind != .node {
			return C.vox_jsc_JSValueMakeNull(runtime.context)
		}
		encoded := state(unsafe { &dom.Node(target) })
		if encoded == '' {
			return C.vox_jsc_JSValueMakeNull(runtime.context)
		}
		return runtime.binding_string(encoded)
	})!
}
