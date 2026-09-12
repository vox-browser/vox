module bindings

import html

fn test_wrapper_world_caches_main_and_isolated_wrappers() {
	main_realm := &html.ScriptingRealm{}
	isolated_realm := &html.ScriptingRealm{}
	mut main_world := WrapperWorld.create(.main)
	mut isolated_world := WrapperWorld.create(.extension)
	register_wrapper_world_for_realm(main_realm, main_world)
	register_wrapper_world_for_realm(isolated_realm, isolated_world)
	mut implementation := Wrappable.create('Node', ['EventTarget'])
	assert implementation.interface_name()! == 'Node'
	assert implementation.fast_is('EventTarget')
	assert implementation.fast_as('Missing') == none

	main_wrapper := wrap(mut main_world, main_realm, mut implementation)
	assert wrap(mut main_world, main_realm, mut implementation) == main_wrapper
	assert main_wrapper.realm() == main_realm
	isolated_wrapper := wrap(mut isolated_world, isolated_realm, mut implementation)
	assert isolated_wrapper != main_wrapper
	assert wrap(mut isolated_world, isolated_realm, mut implementation) == isolated_wrapper
	assert wrappable_impl_from(isolated_wrapper)? == implementation
}

fn test_wrapper_preservation_and_detachment() {
	main_realm := &html.ScriptingRealm{}
	isolated_realm := &html.ScriptingRealm{}
	mut main_world := WrapperWorld.create(.main)
	mut isolated_world := WrapperWorld.create(.internal)
	register_wrapper_world_for_realm(main_realm, main_world)
	register_wrapper_world_for_realm(isolated_realm, isolated_world)
	mut implementation := Wrappable.create('Element', ['Node'])
	main_wrapper := wrap(mut main_world, main_realm, mut implementation)
	isolated_wrapper := wrap(mut isolated_world, isolated_realm, mut implementation)
	preserve_wrapper(mut implementation, main_wrapper)
	preserve_wrapper(mut implementation, isolated_wrapper)
	assert wrapper_is_preserved(main_wrapper)
	assert wrapper_is_preserved(isolated_wrapper)
	isolated_world.detach()
	assert isolated_world.is_detached()
	assert !wrapper_is_preserved(isolated_wrapper)
	assert isolated_world.wrapper_for(implementation, isolated_realm) == none
	assert wrapper_is_preserved(main_wrapper)
	isolated_world.detach()
}

fn test_wrapper_realm_selection_and_prototype_update() {
	preferred_realm := &html.ScriptingRealm{}
	relevant_realm := &html.ScriptingRealm{}
	mut world := WrapperWorld.create(.main)
	register_wrapper_world_for_realm(preferred_realm, world)
	register_wrapper_world_for_realm(relevant_realm, world)
	mut global_implementation := Wrappable.create('Window', [])
	global_wrapper := wrap(mut world, relevant_realm, mut global_implementation)
	mut implementation := Wrappable.create('Location', [])
	implementation.relevant_global_impl_ = global_implementation
	assert wrapper_realm_for_wrappable(world, preferred_realm, implementation) == relevant_realm
	wrapper := wrap(mut world, preferred_realm, mut implementation)
	assert wrapper.realm() == relevant_realm
	mut prototype_impl := Wrappable.create('LocationPrototype', [])
	prototype := wrap(mut world, relevant_realm, mut prototype_impl)
	assert set_prototype_of_cached_main_world_wrapper(mut implementation, prototype)
	assert wrapper.prototype()? == prototype
	assert wrapper_realm_for_node(world, preferred_realm, relevant_realm) == relevant_realm
	assert this_value_realm(preferred_realm, wrapper) == relevant_realm
	assert this_value_realm(preferred_realm, none) == preferred_realm
}

struct WrapperCacheValue {
	name string
}

fn test_wrapper_world_weak_value_cache_surfaces() {
	world := WrapperWorld.create(.main)
	value := &WrapperCacheValue{
		name: 'cached'
	}
	mut cache := WrapperWorldWeakValueCache[WrapperCacheValue]{}
	cache.set(world, value)
	assert cache.get(world)?.name == 'cached'
	cache.set(world, none)
	assert cache.get(world) == none

	key := &WrapperCacheValue{
		name: 'key'
	}
	mut cache_map := WrapperWorldWeakValueCacheMap[WrapperCacheValue, WrapperCacheValue]{}
	mut nested := cache_map.cache_for(key)
	nested.set(world, value)
	assert cache_map.cache_for(key).get(world)? == value
	nested.clear()
	assert nested.get(world) == none
}
