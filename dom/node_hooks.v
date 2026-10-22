module dom

// HTML's behavioral models install these hooks on a small subset of nodes.
// Text and ordinary elements need only the pointer, rather than four inline
// optional callback records.
@[heap]
struct NodeHooks {
mut:
	load_event_delay    ?NodeLoadEventDelayHook
	active_window_proxy ?NodeActiveWindowProxyHook
	adopted_from        ?NodeAdoptedFromHook
	lifecycle           ?NodeLifecycleHook
}

fn (mut n Node) ensure_hooks() &NodeHooks {
	if n.hooks_ == unsafe { nil } { n.hooks_ = &NodeHooks{} }
	return n.hooks_
}
