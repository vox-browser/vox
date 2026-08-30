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
			return
		}
		plugin.run_one_deferred()
	}
}

pub fn (mut plugin EventLoopPlugin) deferred_invoke(function DeferredFunction) {
	plugin.deferred_ << function
}

pub fn (mut plugin EventLoopPlugin) run_one_deferred() bool {
	if plugin.deferred_.len == 0 {
		return false
	}
	function := plugin.deferred_[0]
	plugin.deferred_.delete(0)
	function()
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
