// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/Wrappable.{h,cpp} and WrapperWorld.{h,cpp}.
module bindings

import dom
import html

__global (
	realm_wrapper_worlds                     = map[u64]&WrapperWorld{}
	agent_main_wrapper_worlds                = map[u64]&WrapperWorld{}
	hintless_main_world_wrapper_realms_state = map[string][]u64{}
	non_main_world_preserved_wrappers_state  = map[u64][]PreservedWrapper{}
)

pub enum WrapperWorldType {
	main
	internal
	extension
}

@[heap]
pub struct Wrappable {
pub mut:
	interface_name_           string
	implemented_interfaces_   []string
	supported_property_names_ []string
	origin_                   ?dom.Origin
	relevant_global_impl_     ?&Wrappable
mut:
	main_world_wrapper_                    ?&PlatformObject
	main_world_                            ?&WrapperWorld
	main_world_wrapper_is_preserved_       bool
	has_non_main_world_preserved_wrappers_ bool
}

pub struct PreservedWrapper {
pub:
	world   &WrapperWorld
	wrapper &PlatformObject
}

fn hintless_main_world_wrapper_realms_by_interface() map[string][]u64 {
	return hintless_main_world_wrapper_realms_state
}

fn log_hintless_main_world_wrapper_realm_if_new(wrappable &Wrappable, realm &html.ScriptingRealm) {
	realm_address := u64(voidptr(realm))
	mut seen_realms := hintless_main_world_wrapper_realms_state[wrappable.interface_name_] or {
		[]u64{}
	}
	if realm_address in seen_realms {
		return
	}
	seen_realms << realm_address
	hintless_main_world_wrapper_realms_state[wrappable.interface_name_] = seen_realms
}

fn non_main_world_preserved_wrappers() map[u64][]PreservedWrapper {
	return non_main_world_preserved_wrappers_state
}

pub fn hintless_main_world_wrapper_realm_count(interface_name string) int {
	return hintless_main_world_wrapper_realms_by_interface()[interface_name].len
}

pub fn Wrappable.create(interface_name string, inherited_interfaces []string) &Wrappable {
	mut interfaces := [interface_name]
	for inherited in inherited_interfaces {
		if inherited !in interfaces {
			interfaces << inherited
		}
	}
	return &Wrappable{
		interface_name_: interface_name
		implemented_interfaces_: interfaces
	}
}

pub fn (wrappable &Wrappable) interface_name() !string {
	if wrappable.interface_name_.len == 0 {
		return error('Wrappable has no WebIDL interface')
	}
	return wrappable.interface_name_
}

pub fn (wrappable &Wrappable) implements_interface(interface_name string) bool {
	return interface_name in wrappable.implemented_interfaces_
}

pub fn (wrappable &Wrappable) fast_is(interface_name string) bool {
	return wrappable.implements_interface(interface_name)
}

pub fn (wrappable &Wrappable) fast_as(interface_name string) ?&Wrappable {
	if wrappable.fast_is(interface_name) {
		return wrappable
	}
	return none
}

pub fn (wrappable &Wrappable) extract_an_origin() ?dom.Origin {
	return wrappable.origin_
}

pub fn (wrappable &Wrappable) supported_property_names() []string {
	return wrappable.supported_property_names_.clone()
}

pub fn (wrappable &Wrappable) is_supported_property_name(name string) bool {
	return name in wrappable.supported_property_names_
}

pub fn (wrappable &Wrappable) relevant_global_impl() ?&Wrappable {
	return wrappable.relevant_global_impl_
}

pub fn (_ &Wrappable) main_world_wrapper_offset() uint {
	// The V representation does not expose ABI field offsets.
	return 0
}

pub fn (wrappable &Wrappable) cached_main_world_wrapper() ?&PlatformObject {
	return wrappable.main_world_wrapper_
}

pub fn (wrappable &Wrappable) cached_main_world_wrapper_for(world &WrapperWorld) ?&PlatformObject {
	assert world.is_main_world()
	if cached_world := wrappable.main_world_ {
		assert cached_world == world
	}
	return wrappable.main_world_wrapper_
}

pub fn (mut wrappable Wrappable) set_cached_main_world_wrapper(wrapper &PlatformObject, world &WrapperWorld) {
	assert world.is_main_world()
	if cached := wrappable.main_world_wrapper_ {
		assert cached == wrapper
		cached_world := wrappable.main_world_ or { panic('cached wrapper has no wrapper world') }
		assert cached_world == world
		return
	}
	wrappable.main_world_wrapper_ = wrapper
	wrappable.main_world_ = world
}

pub fn (mut wrappable Wrappable) clear_cached_main_world_wrapper(wrapper &PlatformObject) {
	if cached := wrappable.main_world_wrapper_ {
		if cached != wrapper {
			return
		}
	}
	wrappable.main_world_wrapper_ = none
	wrappable.main_world_ = none
}

pub fn (mut wrappable Wrappable) create_wrapper(realm &html.ScriptingRealm) &PlatformObject {
	mut wrapper := PlatformObject.create(realm)
	if host_defined_for_realm(realm) != none {
		mut intrinsics := host_defined_intrinsics(realm)
		wrapper.set_prototype(intrinsics.ensure_web_prototype(wrappable.interface_name_).object)
	}
	wrapper.set_wrappable_impl(wrappable)
	return wrapper
}

@[heap]
pub struct GCAllocatedWrappable {
	Wrappable
}

pub fn GCAllocatedWrappable.create(interface_name string, inherited_interfaces []string) &GCAllocatedWrappable {
	return &GCAllocatedWrappable{
		Wrappable: *Wrappable.create(interface_name, inherited_interfaces)
	}
}

pub fn (wrappable &GCAllocatedWrappable) main_world_wrapper_is_preserved() bool {
	return wrappable.Wrappable.main_world_wrapper_is_preserved_
}

pub fn (mut wrappable GCAllocatedWrappable) set_main_world_wrapper_is_preserved(value bool) {
	wrappable.Wrappable.main_world_wrapper_is_preserved_ = value
}

pub fn (wrappable &GCAllocatedWrappable) has_non_main_world_preserved_wrappers() bool {
	return wrappable.Wrappable.has_non_main_world_preserved_wrappers_
}

pub fn (mut wrappable GCAllocatedWrappable) set_has_non_main_world_preserved_wrappers(value bool) {
	wrappable.Wrappable.has_non_main_world_preserved_wrappers_ = value
}

pub fn (mut wrappable GCAllocatedWrappable) clear_preserved_wrappers(world &WrapperWorld) {
	wrappable.Wrappable.clear_preserved_wrappers(world)
}

pub fn (mut wrappable GCAllocatedWrappable) finalize() {
	if !wrappable.has_non_main_world_preserved_wrappers() {
		return
	}
	key := wrappable_key(wrappable.Wrappable)
	entries := non_main_world_preserved_wrappers_state[key] or { return }
	for entry in entries {
		mut world := unsafe { &WrapperWorld(entry.world) }
		world.unregister_preserved_wrappable(wrappable.Wrappable)
	}
	non_main_world_preserved_wrappers_state.delete(key)
	wrappable.set_has_non_main_world_preserved_wrappers(false)
}

@[heap]
pub struct WrapperWorld {
pub:
	type_ WrapperWorldType
mut:
	detached_             bool
	wrappers_             map[u64]&PlatformObject
	preserved_wrappables_ map[u64]&Wrappable
}

pub fn WrapperWorld.create(type_ WrapperWorldType) &WrapperWorld {
	return &WrapperWorld{
		type_: type_
	}
}

pub fn (world &WrapperWorld) type_() WrapperWorldType {
	return world.type_
}

pub fn (world &WrapperWorld) is_main_world() bool {
	return world.type_ == .main
}

pub fn (world &WrapperWorld) is_detached() bool {
	return world.detached_
}

fn wrappable_key(wrappable &Wrappable) u64 {
	return u64(voidptr(wrappable))
}

pub fn register_wrapper_world_for_realm(realm &html.ScriptingRealm, world &WrapperWorld) {
	unsafe {
		realm_wrapper_worlds[u64(voidptr(realm))] = world
	}
}

pub fn host_defined_wrapper_world(realm &html.ScriptingRealm) &WrapperWorld {
	if host_defined := host_defined_for_realm(realm) {
		return host_defined.wrapper_world
	}
	return realm_wrapper_worlds[u64(voidptr(realm))] or {
		panic('realm has no registered WrapperWorld')
	}
}

pub fn main_wrapper_world_for_agent(agent &html.Agent) &WrapperWorld {
	key := u64(voidptr(agent))
	if world := agent_main_wrapper_worlds[key] {
		return world
	}
	world := WrapperWorld.create(.main)
	unsafe {
		agent_main_wrapper_worlds[key] = world
	}
	return world
}

pub fn (mut world WrapperWorld) register_preserved_wrappable(wrappable &Wrappable) {
	assert !world.is_main_world()
	assert !world.is_detached()
	unsafe {
		world.preserved_wrappables_[wrappable_key(wrappable)] = wrappable
	}
}

fn (mut world WrapperWorld) unregister_preserved_wrappable(wrappable &Wrappable) {
	world.preserved_wrappables_.delete(wrappable_key(wrappable))
}

fn verify_cache_entry(world &WrapperWorld, wrappable &Wrappable, wrapper &PlatformObject) {
	registered_world := host_defined_wrapper_world(wrapper.realm())
	assert voidptr(registered_world) == voidptr(world)
	implementation := wrappable_impl_from(wrapper) or { panic('wrapper has no implementation') }
	assert voidptr(implementation) == voidptr(wrappable)
}

pub fn (world &WrapperWorld) wrapper_for(wrappable &Wrappable, realm &html.ScriptingRealm) ?&PlatformObject {
	if world.is_main_world() {
		return wrappable.cached_main_world_wrapper_for(world)
	}
	wrapper := world.wrappers_[wrappable_key(wrappable)] or { return none }
	assert wrapper.realm() == realm
	return wrapper
}

pub fn (mut world WrapperWorld) set_wrapper(mut wrappable Wrappable, wrapper &PlatformObject) {
	assert !world.is_detached()
	verify_cache_entry(world, wrappable, wrapper)
	if world.is_main_world() {
		wrappable.set_cached_main_world_wrapper(wrapper, world)
		return
	}
	key := wrappable_key(wrappable)
	if existing := world.wrappers_[key] {
		assert existing == wrapper
		assert existing.realm() == wrapper.realm()
		return
	}
	unsafe {
		world.wrappers_[key] = wrapper
	}
}

pub fn (mut world WrapperWorld) clear_wrapper(mut wrappable Wrappable, wrapper &PlatformObject) {
	verify_cache_entry(world, wrappable, wrapper)
	if world.is_main_world() {
		wrappable.clear_cached_main_world_wrapper(wrapper)
		return
	}
	key := wrappable_key(wrappable)
	if existing := world.wrappers_[key] {
		assert existing == wrapper
		world.wrappers_.delete(key)
	}
}

pub fn (mut world WrapperWorld) detach() {
	assert !world.is_main_world()
	if world.detached_ {
		return
	}
	world.detached_ = true
	for _, wrappable in world.preserved_wrappables_ {
		mut mutable_wrappable := unsafe { &Wrappable(wrappable) }
		mutable_wrappable.clear_preserved_wrappers(world)
	}
	world.preserved_wrappables_.clear()
	world.wrappers_.clear()
}

pub fn (world &WrapperWorld) finalize(collecting_everything bool) {
	assert world.is_main_world() || world.is_detached() || world.preserved_wrappables_.len == 0
		|| collecting_everything
}

pub struct WrapperWorldWeakValueCache[T] {
mut:
	values_ map[u64]&T
}

pub fn (cache &WrapperWorldWeakValueCache[T]) get(world &WrapperWorld) ?&T {
	return cache.values_[u64(voidptr(world))] or { none }
}

pub fn (mut cache WrapperWorldWeakValueCache[T]) set(world &WrapperWorld, value ?&T) {
	key := u64(voidptr(world))
	if item := value {
		unsafe {
			cache.values_[key] = item
		}
	} else {
		cache.values_.delete(key)
	}
}

pub fn (cache &WrapperWorldWeakValueCache[T]) for_each(callback fn (&T)) {
	for _, value in cache.values_ {
		callback(value)
	}
}

pub fn (mut cache WrapperWorldWeakValueCache[T]) clear() {
	cache.values_.clear()
}

pub struct WrapperWorldWeakValueCacheMap[K, V] {
mut:
	entries_ map[u64]&WrapperWorldWeakValueCache[V]
}

pub fn (mut cache_map WrapperWorldWeakValueCacheMap[K, V]) cache_for(key &K) &WrapperWorldWeakValueCache[V] {
	identity := u64(voidptr(key))
	if existing := cache_map.entries_[identity] {
		return existing
	}
	cache := &WrapperWorldWeakValueCache[V]{}
	unsafe {
		cache_map.entries_[identity] = cache
	}
	return cache
}

pub fn (cache_map &WrapperWorldWeakValueCacheMap[K, V]) for_each(callback fn (&WrapperWorldWeakValueCache[V])) {
	for _, cache in cache_map.entries_ {
		callback(cache)
	}
}

pub fn create_wrapper_for_wrappable(realm &html.ScriptingRealm, mut wrappable Wrappable) &PlatformObject {
	return wrappable.create_wrapper(realm)
}

pub fn create_global_object_wrapper(realm &html.ScriptingRealm, mut wrappable Wrappable) &PlatformObject {
	return wrappable.create_wrapper(realm)
}

pub fn wrapper_realm_for_node(world &WrapperWorld, preferred_realm &html.ScriptingRealm, node_realm &html.ScriptingRealm) &html.ScriptingRealm {
	if relevant_world := realm_wrapper_worlds[u64(voidptr(node_realm))] {
		if relevant_world == world {
			return node_realm
		}
	}
	return preferred_realm
}

pub fn wrapper_realm_for_wrappable(world &WrapperWorld, preferred_realm &html.ScriptingRealm, wrappable &Wrappable) &html.ScriptingRealm {
	if !world.is_main_world() {
		return preferred_realm
	}
	if relevant_global := wrappable.relevant_global_impl() {
		if wrapper := relevant_global.cached_main_world_wrapper() {
			if wrapper_world := realm_wrapper_worlds[u64(voidptr(wrapper.realm()))] {
				if wrapper_world == world {
					return wrapper.realm()
				}
			}
		}
	}
	return preferred_realm
}

pub fn wrap(mut world WrapperWorld, preferred_realm &html.ScriptingRealm, mut wrappable Wrappable) &PlatformObject {
	if cached := world.wrapper_for(wrappable, preferred_realm) {
		return cached
	}
	actual_realm := wrapper_realm_for_wrappable(world, preferred_realm, wrappable)
	if !world.is_main_world() {
		if cached := world.wrapper_for(wrappable, actual_realm) {
			return cached
		}
	}
	wrapper := wrappable.create_wrapper(actual_realm)
	if world.is_main_world() && !wrappable.implements_interface('Node')
		&& wrappable.relevant_global_impl() == none {
		log_hintless_main_world_wrapper_realm_if_new(wrappable, actual_realm)
	}
	world.set_wrapper(mut wrappable, wrapper)
	return wrapper
}

pub fn this_value_realm(fallback_realm &html.ScriptingRealm, value ?&PlatformObject) &html.ScriptingRealm {
	object := value or { return fallback_realm }
	return object.realm()
}

pub fn set_prototype_of_cached_main_world_wrapper(mut wrappable Wrappable, prototype &PlatformObject) bool {
	if mut wrapper := wrappable.main_world_wrapper_ {
		wrapper_world := realm_wrapper_worlds[u64(voidptr(wrapper.realm()))] or { return true }
		prototype_world := realm_wrapper_worlds[u64(voidptr(prototype.realm()))] or { return true }
		if !wrapper_world.is_main_world() || !prototype_world.is_main_world() {
			return true
		}
		wrapper.set_prototype(prototype)
	}
	return true
}

pub fn preserve_wrapper(mut wrappable Wrappable, wrapper &PlatformObject) {
	world := host_defined_wrapper_world(wrapper.realm())
	if world.is_detached() {
		return
	}
	if world.is_main_world() {
		cached := wrappable.main_world_wrapper_ or { panic('main-world wrapper was not cached') }
		assert cached == wrapper
		wrappable.main_world_wrapper_is_preserved_ = true
		return
	}
	key := wrappable_key(wrappable)
	mut entries := non_main_world_preserved_wrappers_state[key] or { []PreservedWrapper{} }
	for entry in entries {
		if voidptr(entry.wrapper) == voidptr(wrapper) && voidptr(entry.world) == voidptr(world) {
			return
		}
	}
	entries << PreservedWrapper{
		world: world
		wrapper: wrapper
	}
	non_main_world_preserved_wrappers_state[key] = entries
	wrappable.has_non_main_world_preserved_wrappers_ = true
	mut mutable_world := unsafe { &WrapperWorld(world) }
	mutable_world.register_preserved_wrappable(wrappable)
}

pub fn wrapper_is_preserved(wrapper &PlatformObject) bool {
	wrappable := wrapper.wrappable_impl() or { return false }
	world := host_defined_wrapper_world(wrapper.realm())
	if world.is_main_world() {
		cached := wrappable.main_world_wrapper_ or { return false }
		return wrappable.main_world_wrapper_is_preserved_ && cached == wrapper
	}
	if !wrappable.has_non_main_world_preserved_wrappers_ {
		return false
	}
	entries := non_main_world_preserved_wrappers()[wrappable_key(wrappable)] or { return false }
	for entry in entries {
		if voidptr(entry.wrapper) == voidptr(wrapper) && voidptr(entry.world) == voidptr(world) {
			return true
		}
	}
	return false
}

pub fn (mut wrappable Wrappable) clear_preserved_wrappers(world &WrapperWorld) {
	assert !world.is_main_world()
	key := wrappable_key(wrappable)
	entries := non_main_world_preserved_wrappers_state[key] or { return }
	mut remaining := []PreservedWrapper{}
	for entry in entries {
		if voidptr(entry.world) != voidptr(world) {
			remaining << entry
		}
	}
	if remaining.len == 0 {
		non_main_world_preserved_wrappers_state.delete(key)
		wrappable.has_non_main_world_preserved_wrappers_ = false
	} else {
		non_main_world_preserved_wrappers_state[key] = remaining
	}
}

pub fn cache_global_object_wrapper(realm &html.ScriptingRealm) {
	if realm.global_object_handle == unsafe { nil } {
		panic('realm has no global object wrapper')
	}
	wrapper := unsafe { &PlatformObject(realm.global_object_handle) }
	mut wrappable := wrapper.wrappable_impl() or { panic('global wrapper has no implementation') }
	mut world := host_defined_wrapper_world(realm)
	world.set_wrapper(mut wrappable, wrapper)
}

pub fn wrappable_impl_from(object &PlatformObject) ?&Wrappable {
	return object.wrappable_impl()
}
