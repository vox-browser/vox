module browserjs

import platform

fn register_runtime_binding[T](mut bindings map[voidptr]T, owner voidptr, binding T) {
	// The lookup table is shared by realms. Its backing storage must survive
	// retirement of whichever document first inserts or grows it.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	bindings[owner] = binding
}

fn unregister_runtime_binding[T](mut bindings map[voidptr]T, owner voidptr) {
	// Removing an entry can allocate deletion metadata or rehash survivors.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	bindings.delete(owner)
}
