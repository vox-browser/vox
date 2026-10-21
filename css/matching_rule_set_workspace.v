module css

import platform

// Only the vectors of matching-rule references live here. Matching itself can
// lazily publish declarations, selector metadata and scope caches, so it keeps
// allocating in the caller's owner. Public rule queries retain their output.
@[heap]
struct MatchingRuleSetWorkspacePool {
mut:
	arenas []&platform.Arena
	depth int
}

struct MatchingRuleSetWorkspace {
	arena &platform.Arena = unsafe { nil }
mut:
	pool &MatchingRuleSetWorkspacePool = unsafe { nil }
}

fn (computer &StyleComputer) acquire_matching_rule_set_workspace() MatchingRuleSetWorkspace {
	$if prealloc {
		mut mutable_computer := unsafe { &StyleComputer(computer) }
		if mutable_computer.matching_rule_sets_ == unsafe { nil } {
			persistent := platform.enter_persistent()
			pool := &MatchingRuleSetWorkspacePool{}
			mutable_computer.matching_rule_sets_ = pool
			if computer.document_ != unsafe { nil } {
				mut owner := computer.document_.native_storage()
				if owner != unsafe { nil } {
					owner.add_cleanup(fn [pool] () {
						assert pool.depth == 0
						for index in 0 .. pool.arenas.len {
							mut arena := pool.arenas[index]
							arena.release()
						}
					})
				}
			}
			platform.leave_persistent(persistent)
		}
		mut pool := mutable_computer.matching_rule_sets_
		if pool.depth == pool.arenas.len {
			persistent := platform.enter_persistent()
			pool.arenas << platform.new_arena('matching rule lists')
			platform.leave_persistent(persistent)
		}
		arena := pool.arenas[pool.depth]
		pool.depth++
		return MatchingRuleSetWorkspace{arena: arena, pool: pool}
	}
	return MatchingRuleSetWorkspace{}
}

fn (mut workspace MatchingRuleSetWorkspace) finish() {
	if workspace.pool == unsafe { nil } { return }
	mut pool := workspace.pool
	assert pool.depth > 0 && voidptr(pool.arenas[pool.depth - 1]) == voidptr(workspace.arena)
	mut arena := workspace.arena
	arena.reset()
	pool.depth--
	workspace.pool = unsafe { nil }
}

fn append_scoped_matching_rule(mut rules []ScopedMatchingRule, rule ScopedMatchingRule,
	storage &platform.Arena) {
	if storage == unsafe { nil } { rules << rule; return }
	mut arena := unsafe { &platform.Arena(storage) }
	entry := arena.enter()
	rules << rule
	arena.leave(entry)
}

fn append_matching_layer(mut layers []LayerMatchingRules, layer LayerMatchingRules,
	storage &platform.Arena) {
	if storage == unsafe { nil } { layers << layer; return }
	mut arena := unsafe { &platform.Arena(storage) }
	entry := arena.enter()
	layers << layer
	arena.leave(entry)
}
