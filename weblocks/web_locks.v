// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebLocks/{AbstractOperations,Lock,LockManager,LockRequest,
// NavigatorLocks}.{h,cpp,idl}. JavaScript promises enter through the typed
// promise records below; the lock and callback task queues preserve the
// ordering of the upstream algorithms.
module weblocks

import dom

pub enum LockMode {
	shared
	exclusive
}

pub struct LockOptions {
pub:
	mode         LockMode = .exclusive
	if_available bool
	steal        bool
	signal       ?&dom.AbortSignal
}

pub enum LockPromiseState {
	pending
	fulfilled
	rejected
}

pub enum LockCallbackState {
	pending
	fulfilled
	rejected
}

pub struct LockCallbackResult {
pub:
	state  LockCallbackState
	value  string
	reason string
}

pub fn pending_callback_result() LockCallbackResult {
	return LockCallbackResult{ state: .pending }
}

pub fn fulfilled_callback_result(value string) LockCallbackResult {
	return LockCallbackResult{
		state: .fulfilled
		value: value
	}
}

pub fn rejected_callback_result(reason string) LockCallbackResult {
	return LockCallbackResult{
		state: .rejected
		reason: reason
	}
}

pub type LockGrantedCallback = fn (?&Lock) LockCallbackResult

@[heap]
pub struct LockPromise {
mut:
	state_                    LockPromiseState
	value_                    string
	reason_                   string
	callback_invocations_     int
	last_callback_had_lock_   bool
	awaiting_callback_result_ bool
}

fn LockPromise.pending() &LockPromise {
	return &LockPromise{}
}

fn LockPromise.rejected(reason string) &LockPromise {
	return &LockPromise{
		state_: .rejected
		reason_: reason
	}
}

pub fn (promise &LockPromise) state() LockPromiseState {
	return promise.state_
}

pub fn (promise &LockPromise) value() string {
	return promise.value_
}

pub fn (promise &LockPromise) reason() string {
	return promise.reason_
}

pub fn (promise &LockPromise) callback_invocations() int {
	return promise.callback_invocations_
}

pub fn (promise &LockPromise) last_callback_had_lock() bool {
	return promise.last_callback_had_lock_
}

fn (mut promise LockPromise) resolve(value string) {
	if promise.state_ != .pending {
		return
	}
	promise.state_ = .fulfilled
	promise.value_ = value
	promise.awaiting_callback_result_ = false
}

fn (mut promise LockPromise) reject(reason string) {
	if promise.state_ != .pending {
		return
	}
	promise.state_ = .rejected
	promise.reason_ = reason
	promise.awaiting_callback_result_ = false
}

pub struct LockInfo {
pub:
	name      string
	mode      LockMode
	client_id string
}

pub struct LockManagerSnapshot {
pub:
	held    []LockInfo
	pending []LockInfo
}

@[heap]
pub struct LockQueryPromise {
mut:
	state_    LockPromiseState
	snapshot_ LockManagerSnapshot
	reason_   string
}

fn LockQueryPromise.pending() &LockQueryPromise {
	return &LockQueryPromise{}
}

fn LockQueryPromise.rejected(reason string) &LockQueryPromise {
	return &LockQueryPromise{
		state_: .rejected
		reason_: reason
	}
}

pub fn (promise &LockQueryPromise) state() LockPromiseState {
	return promise.state_
}

pub fn (promise &LockQueryPromise) snapshot() LockManagerSnapshot {
	return promise.snapshot_
}

pub fn (promise &LockQueryPromise) reason() string {
	return promise.reason_
}

@[heap]
pub struct LockEnvironment {
pub:
	client_id string
pub mut:
	fully_active bool = true
mut:
	lock_manager_ &LockManager = unsafe { nil }
}

@[heap]
pub struct LockData {
pub:
	client_id        string
	manager          &LockManager
	mode_            LockMode
	name_            string
	released_promise &LockPromise
	waiting_promise  &LockPromise
}

@[heap]
pub struct Lock {
pub:
	lock_data &LockData
}

pub fn Lock.create(lock_data &LockData) &Lock {
	return &Lock{ lock_data: lock_data }
}

// https://w3c.github.io/web-locks/#dom-lock-name
pub fn (lock_data &Lock) name() string {
	return lock_data.lock_data.name_
}

// https://w3c.github.io/web-locks/#dom-lock-mode
pub fn (lock_data &Lock) mode() LockMode {
	return lock_data.lock_data.mode_
}

pub fn (lock_data &LockData) client_id() string {
	return lock_data.client_id
}

pub fn (lock_data &LockData) name() string {
	return lock_data.name_
}

pub fn (lock_data &LockData) mode() LockMode {
	return lock_data.mode_
}

pub fn (lock_data &LockData) released_promise() &LockPromise {
	return lock_data.released_promise
}

pub fn (lock_data &LockData) waiting_promise() &LockPromise {
	return lock_data.waiting_promise
}

@[heap]
pub struct LockRequest {
pub:
	client_id_   string
	manager_     &LockManager
	name_        string
	mode_        LockMode
	callback_    LockGrantedCallback @[required]
	promise_     &LockPromise
	signal_      ?&dom.AbortSignal
	if_available bool
	steal        bool
mut:
	abort_algorithm_id_ ?u64
}

pub fn (request &LockRequest) name() string {
	return request.name_
}

pub fn (request &LockRequest) mode() LockMode {
	return request.mode_
}

pub fn (request &LockRequest) client_id() string {
	return request.client_id_
}

pub fn (request &LockRequest) manager() &LockManager {
	return request.manager_
}

pub fn (request &LockRequest) callback() LockGrantedCallback {
	return request.callback_
}

pub fn (request &LockRequest) promise() &LockPromise {
	return request.promise_
}

pub fn (request &LockRequest) signal() ?&dom.AbortSignal {
	return request.signal_
}

pub fn (request &LockRequest) abort_algorithm_id() ?u64 {
	return request.abort_algorithm_id_
}

pub fn (mut request LockRequest) set_abort_algorithm_id(id ?u64) {
	request.abort_algorithm_id_ = id
}

enum WebLocksTaskKind {
	request_lock
	invoke_callback
	abort_request
	release_lock
	snapshot_lock_state
}

struct WebLocksTask {
	kind          WebLocksTaskKind
	request       &LockRequest = unsafe { nil }
	lock_data     &LockData = unsafe { nil }
	query_promise &LockQueryPromise = unsafe { nil }
	null_lock     bool
}

@[heap]
pub struct LockManager {
pub:
	environment &LockEnvironment
mut:
	held_lock_set_          []&LockData
	lock_request_queue_map_ map[string][]&LockRequest
	lock_tasks              []WebLocksTask
	callback_tasks          []WebLocksTask
}

pub fn LockManager.create(environment &LockEnvironment) &LockManager {
	return &LockManager{
		environment: environment
	}
}

// https://w3c.github.io/web-locks/#obtain-a-lock-manager
pub fn obtain_lock_manager(environment &LockEnvironment) &LockManager {
	mut mutable_environment := unsafe { &LockEnvironment(environment) }
	if isnil(mutable_environment.lock_manager_) {
		mutable_environment.lock_manager_ = LockManager.create(environment)
	}
	return mutable_environment.lock_manager_
}

// https://w3c.github.io/web-locks/#get-the-lock-request-queue
pub fn get_lock_request_queue(queue_map map[string][]&LockRequest, name string) []&LockRequest {
	return (queue_map[name] or { []&LockRequest{} }).clone()
}

pub fn (manager &LockManager) held_lock_set() []&LockData {
	return manager.held_lock_set_.clone()
}

pub fn (manager &LockManager) lock_request_queue_map() map[string][]&LockRequest {
	return manager.lock_request_queue_map_.clone()
}

pub fn (manager &LockManager) pending_lock_count(name string) int {
	return (manager.lock_request_queue_map_[name] or { []&LockRequest{} }).len
}

pub fn (manager &LockManager) relevant_realm() &LockEnvironment {
	return manager.environment
}

pub fn (manager &LockManager) relevant_global_impl() &LockEnvironment {
	return manager.environment
}

// https://w3c.github.io/web-locks/#lock-task-queue
pub fn (manager &LockManager) lock_task_queue() int {
	return manager.lock_tasks.len
}

pub fn (mut manager LockManager) queue_web_locks_task(task WebLocksTask) {
	manager.lock_tasks << task
}

pub fn (mut manager LockManager) queue_web_locks_task_on_relevant_event_loop(task WebLocksTask) {
	manager.callback_tasks << task
}

pub fn (manager &LockManager) has_queued_tasks() bool {
	return manager.lock_tasks.len > 0 || manager.callback_tasks.len > 0
}

pub fn (mut manager LockManager) run_next_task() bool {
	if manager.lock_tasks.len > 0 {
		task := manager.lock_tasks[0]
		manager.lock_tasks.delete(0)
		manager.run_task(task)
		return true
	}
	if manager.callback_tasks.len > 0 {
		task := manager.callback_tasks[0]
		manager.callback_tasks.delete(0)
		manager.run_task(task)
		return true
	}
	return false
}

pub fn (mut manager LockManager) run_until_idle() {
	for manager.run_next_task() {
	}
}

fn (mut manager LockManager) run_task(task WebLocksTask) {
	match task.kind {
		.request_lock {
			manager.run_request_lock(task.request)
		}
		.invoke_callback {
			manager.invoke_callback(task.request, task.lock_data, task.null_lock)
		}
		.abort_request {
			mut request := unsafe { &LockRequest(task.request) }
			request.abort_request()
		}
		.release_lock {
			task.lock_data.release_lock()
		}
		.snapshot_lock_state {
			mut query_promise := unsafe { &LockQueryPromise(task.query_promise) }
			manager.snapshot_lock_state(mut query_promise)
		}
	}
}

// https://w3c.github.io/web-locks/#dom-lockmanager-request
pub fn (mut manager LockManager) request(name string, options LockOptions, callback LockGrantedCallback) &LockPromise {
	if !manager.environment.fully_active {
		return LockPromise.rejected('InvalidStateError: Document is not fully active')
	}
	if name.starts_with('-') {
		return LockPromise.rejected("NotSupportedError: Lock names starting with '-' are reserved")
	}
	if options.steal && options.if_available {
		return LockPromise.rejected("NotSupportedError: Lock options 'steal' and 'ifAvailable' cannot both be true")
	}
	if options.steal && options.mode != .exclusive {
		return LockPromise.rejected("NotSupportedError: Lock option 'steal' can only be used with exclusive locks")
	}
	if options.signal != none && (options.steal || options.if_available) {
		return LockPromise.rejected("NotSupportedError: Lock option 'signal' cannot be combined with 'steal' or 'ifAvailable'")
	}
	if signal := options.signal {
		if signal.aborted() {
			return LockPromise.rejected(signal.reason().to_string_value())
		}
	}
	promise := LockPromise.pending()
	manager.request_lock(promise, callback, name, options.mode, options.if_available, options.steal, options.signal)
	return promise
}

pub fn (mut manager LockManager) request_with_defaults(name string, callback LockGrantedCallback) &LockPromise {
	return manager.request(name, LockOptions{}, callback)
}

// https://w3c.github.io/web-locks/#dom-lockmanager-query
pub fn (mut manager LockManager) query() &LockQueryPromise {
	if !manager.environment.fully_active {
		return LockQueryPromise.rejected('InvalidStateError: Document is not fully active')
	}
	promise := LockQueryPromise.pending()
	manager.queue_web_locks_task(WebLocksTask{
		kind: .snapshot_lock_state
		query_promise: promise
	})
	return promise
}

// https://w3c.github.io/web-locks/#request-a-lock
pub fn (mut manager LockManager) request_lock(promise &LockPromise, callback LockGrantedCallback, name string, mode LockMode, if_available bool, steal bool, signal ?&dom.AbortSignal) &LockRequest {
	mut request := &LockRequest{
		client_id_: manager.environment.client_id
		manager_: manager
		name_: name
		mode_: mode
		callback_: callback
		promise_: promise
		signal_: signal
		if_available: if_available
		steal: steal
	}
	if mut abort_signal := signal {
		request_pointer := request
		signal_pointer := abort_signal
		algorithm_id := abort_signal.add_abort_algorithm(fn [request_pointer, signal_pointer] () {
			mut mutable_request := unsafe { &LockRequest(request_pointer) }
			mutable_request.signal_to_abort_request(signal_pointer)
		})
		request.set_abort_algorithm_id(algorithm_id)
	}
	manager.queue_web_locks_task(WebLocksTask{
		kind: .request_lock
		request: request
	})
	return request
}

fn (mut manager LockManager) run_request_lock(request &LockRequest) {
	mut queue := get_lock_request_queue(manager.lock_request_queue_map_, request.name_)
	if request.steal {
		mut retained := []&LockData{}
		for held_lock in manager.held_lock_set_ {
			if held_lock.name_ == request.name_ {
				mut released := unsafe { &LockPromise(held_lock.released_promise) }
				released.reject('AbortError: Lock was stolen')
			} else {
				retained << held_lock
			}
		}
		manager.held_lock_set_ = retained
		queue.prepend(request)
	} else {
		if request.if_available && !request.is_grantable(queue) {
			manager.queue_web_locks_task_on_relevant_event_loop(WebLocksTask{
				kind: .invoke_callback
				request: request
				null_lock: true
			})
			return
		}
		queue << request
	}
	manager.lock_request_queue_map_[request.name_] = queue
	manager.process_lock_request_queue(request.name_)
}

// https://w3c.github.io/web-locks/#process-the-lock-request-queue
pub fn (mut manager LockManager) process_lock_request_queue(name string) {
	mut queue := get_lock_request_queue(manager.lock_request_queue_map_, name)
	for queue.len > 0 {
		request := queue[0]
		if !request.is_grantable(queue) {
			break
		}
		queue.delete(0)
		waiting := LockPromise.pending()
		lock_data := &LockData{
			client_id: request.client_id_
			manager: manager
			mode_: request.mode_
			name_: request.name_
			released_promise: request.promise_
			waiting_promise: waiting
		}
		manager.held_lock_set_ << lock_data
		manager.queue_web_locks_task_on_relevant_event_loop(WebLocksTask{
			kind: .invoke_callback
			request: request
			lock_data: lock_data
		})
	}
	manager.lock_request_queue_map_[name] = queue
}

fn (mut manager LockManager) invoke_callback(request &LockRequest, lock_data &LockData, null_lock bool) {
	mut released := unsafe { &LockPromise(request.promise_) }
	released.callback_invocations_++
	released.last_callback_had_lock_ = !null_lock
	if null_lock {
		result := request.callback_(none)
		manager.apply_callback_result(mut released, result, unsafe { nil })
		return
	}
	if signal := request.signal_ {
		if signal.aborted() {
			manager.queue_web_locks_task(WebLocksTask{
				kind: .release_lock
				lock_data: lock_data
			})
			return
		}
		if algorithm_id := request.abort_algorithm_id_ {
			mut mutable_signal := unsafe { &dom.AbortSignal(signal) }
			mutable_signal.remove_abort_algorithm(algorithm_id)
		}
	}
	result := request.callback_(Lock.create(lock_data))
	mut waiting := unsafe { &LockPromise(lock_data.waiting_promise) }
	manager.apply_callback_result(mut waiting, result, lock_data)
}

fn (mut manager LockManager) apply_callback_result(mut promise LockPromise, result LockCallbackResult, lock_data &LockData) {
	match result.state {
		.pending {
			promise.awaiting_callback_result_ = true
		}
		.fulfilled {
			promise.resolve(result.value)
			if !isnil(lock_data) {
				manager.queue_web_locks_task(WebLocksTask{
					kind: .release_lock
					lock_data: lock_data
				})
			}
		}
		.rejected {
			promise.reject(result.reason)
			if !isnil(lock_data) {
				manager.queue_web_locks_task(WebLocksTask{
					kind: .release_lock
					lock_data: lock_data
				})
			}
		}
	}
}

// Settles the promise returned by a callback that previously reported pending.
pub fn (mut manager LockManager) settle_callback_result(released_promise &LockPromise, result LockCallbackResult) bool {
	for held_lock in manager.held_lock_set_ {
		if held_lock.released_promise == released_promise {
			mut waiting := unsafe { &LockPromise(held_lock.waiting_promise) }
			if !waiting.awaiting_callback_result_ {
				return false
			}
			manager.apply_callback_result(mut waiting, result, held_lock)
			return result.state != .pending
		}
	}
	mut released := unsafe { &LockPromise(released_promise) }
	if released.awaiting_callback_result_ {
		manager.apply_callback_result(mut released, result, unsafe { nil })
		return result.state != .pending
	}
	return false
}

// https://w3c.github.io/web-locks/#release-the-lock
pub fn (lock_data &LockData) release_lock() {
	mut manager := unsafe { &LockManager(lock_data.manager) }
	manager.held_lock_set_ = manager.held_lock_set_.filter(it != lock_data)
	mut released := unsafe { &LockPromise(lock_data.released_promise) }
	waiting := lock_data.waiting_promise
	if waiting.state_ == .fulfilled {
		released.resolve(waiting.value_)
	} else if waiting.state_ == .rejected {
		released.reject(waiting.reason_)
	}
	manager.process_lock_request_queue(lock_data.name_)
}

// https://w3c.github.io/web-locks/#abort-the-request
pub fn (mut request LockRequest) abort_request() {
	mut manager := unsafe { &LockManager(request.manager_) }
	mut queue := get_lock_request_queue(manager.lock_request_queue_map_, request.name_)
	queue = queue.filter(it != request)
	manager.lock_request_queue_map_[request.name_] = queue
	manager.process_lock_request_queue(request.name_)
}

// https://w3c.github.io/web-locks/#signal-to-abort-the-request
pub fn (mut request LockRequest) signal_to_abort_request(signal &dom.AbortSignal) {
	mut manager := unsafe { &LockManager(request.manager_) }
	manager.queue_web_locks_task(WebLocksTask{
		kind: .abort_request
		request: request
	})
	mut promise := unsafe { &LockPromise(request.promise_) }
	promise.reject(signal.reason().to_string_value())
}

// https://w3c.github.io/web-locks/#grantable
pub fn (request &LockRequest) is_grantable(queue []&LockRequest) bool {
	if queue.len > 0 && queue[0] != request {
		return false
	}
	held := request.manager_.held_lock_set_
	if request.mode_ == .exclusive {
		return !held.any(it.name_ == request.name_)
	}
	return !held.any(it.name_ == request.name_ && it.mode_ == .exclusive)
}

// https://w3c.github.io/web-locks/#snapshot-the-lock-state
pub fn (manager &LockManager) snapshot_lock_state(mut promise LockQueryPromise) {
	mut pending := []LockInfo{}
	for _, queue in manager.lock_request_queue_map_ {
		for request in queue {
			pending << LockInfo{
				name: request.name_
				mode: request.mode_
				client_id: request.client_id_
			}
		}
	}
	mut held := []LockInfo{}
	for lock_data in manager.held_lock_set_ {
		held << LockInfo{
			name: lock_data.name_
			mode: lock_data.mode_
			client_id: lock_data.client_id
		}
	}
	promise.snapshot_ = LockManagerSnapshot{
		held: held
		pending: pending
	}
	promise.state_ = .fulfilled
}

@[heap]
pub struct NavigatorLocks {
pub:
	environment &LockEnvironment
}

pub fn NavigatorLocks.create(environment &LockEnvironment) &NavigatorLocks {
	return &NavigatorLocks{ environment: environment }
}

// https://w3c.github.io/web-locks/#dom-navigatorlocks-locks
pub fn (navigator &NavigatorLocks) locks() &LockManager {
	return obtain_lock_manager(navigator.environment)
}
