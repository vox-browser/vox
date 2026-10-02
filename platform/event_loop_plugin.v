// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Platform/EventLoopPlugin.{h,cpp}.
module platform

__global platform_event_loop_plugin &EventLoopPlugin

pub type GoalCondition = fn () bool

pub type DeferredFunction = fn ()

@[heap]
pub struct EventLoopPlugin {
mut:
	deferred_      []DeferredFunction
	deferred_timer_ ?&Timer
	exit_requested bool
}

pub fn EventLoopPlugin.new() &EventLoopPlugin {
	return &EventLoopPlugin{}
}

pub fn EventLoopPlugin.the() &EventLoopPlugin {
	if platform_event_loop_plugin == unsafe { nil } {
		panic('EventLoopPlugin is not installed')
	}
	return platform_event_loop_plugin
}

pub fn EventLoopPlugin.is_installed() bool {
	return platform_event_loop_plugin != unsafe { nil }
}

pub fn EventLoopPlugin.install(plugin &EventLoopPlugin) {
	if platform_event_loop_plugin != unsafe { nil } {
		panic('EventLoopPlugin already installed')
	}
	platform_event_loop_plugin = plugin
}

pub fn (mut plugin EventLoopPlugin) spin_until(goal GoalCondition) {
	for !goal() {
		if plugin.exit_requested {
			return
		}
		if plugin.deferred_.len == 0 {
			if native_timer_scheduling_available() {
				pump_native_events(0.05)
				continue
			}
			return
		}
		plugin.run_one_deferred()
	}
}

pub fn (mut plugin EventLoopPlugin) deferred_invoke(function DeferredFunction) {
	plugin.deferred_ << function
	plugin.schedule_deferred_delivery()
}

fn (mut plugin EventLoopPlugin) schedule_deferred_delivery() {
	if plugin.deferred_timer_ == none {
		plugin.deferred_timer_ = Timer.create_single_shot(0, fn [mut plugin] () {
			// Core::ThreadEventQueue::process moves its pending event list before
			// invoking callbacks. Work added during delivery gets a later turn.
			functions := plugin.deferred_.clone()
			plugin.deferred_.clear()
			for function in functions { function() }
		})
	}
	mut timer := plugin.deferred_timer_ or { return }
	if !timer.is_active() { timer.restart() }
}

pub fn (mut plugin EventLoopPlugin) run_one_deferred() bool {
	if plugin.deferred_.len == 0 {
		return false
	}
	function := plugin.deferred_[0]
	plugin.deferred_.delete(0)
	if mut timer := plugin.deferred_timer_ { timer.stop() }
	function()
	if plugin.deferred_.len > 0 { plugin.schedule_deferred_delivery() }
	return true
}

pub fn (mut plugin EventLoopPlugin) quit() {
	plugin.exit_requested = true
}

pub struct EventLoopPluginRegistry {
mut:
	plugin ?&EventLoopPlugin
}

pub fn (mut registry EventLoopPluginRegistry) install(plugin &EventLoopPlugin) {
	if registry.plugin != none {
		panic('EventLoopPlugin already installed')
	}
	registry.plugin = plugin
}

pub fn (registry &EventLoopPluginRegistry) get() &EventLoopPlugin {
	return registry.plugin or { panic('EventLoopPlugin is not installed') }
}
