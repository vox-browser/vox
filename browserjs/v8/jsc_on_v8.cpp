// SPDX-License-Identifier: BSD-2-Clause
// JavaScriptCore C API implemented on V8.
//
// Vox's bindings call the JSC C API directly from ~150 V/C files. A `-d vox_v8`
// build compiles them against include/JavaScriptCore/JavaScript.h and links this
// library instead of JavaScriptCore.framework, so the same browser runs on V8.
//
// Value handles. JSC values stay valid while they are reachable from the C stack
// (conservative scanning), from JSValueProtect, or from the JS heap; objects
// never move. V8 needs explicit handles and moves objects, so every JSValueRef
// here is a Box:
//  - undefined/null/true/false are process-wide constant boxes;
//  - numbers carry their double inline;
//  - strings/symbols/BigInts own a v8::Global and live until the end of the
//    current run-loop turn, or longer while protected;
//  - each object has exactly one canonical Box (found through its identity
//    hash), so pointer identity matches JSC. A Box is strong during the turn in
//    which it was last handed out and while protected; afterwards its handle is
//    weak and the Box is freed only when V8 collects the object. As in JSC, an
//    unprotected object pointer therefore stays valid while the object lives.
// A CFRunLoop BeforeWaiting observer on the isolate's thread ends the turn at
// the outermost run-loop level, where no V frame can still hold a temporary.
#include <v8.h>
#include <libplatform/libplatform.h>

#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "include/JavaScriptCore/JavaScript.h"
#include "include/JavaScriptCore/JSStringRefCF.h"
extern "C" {
#include "../module_loader_darwin.h"
}

struct Loader;
struct OpaqueJSContext;
void close_loader(OpaqueJSContext* ctx);
v8::MaybeLocal<v8::Promise> vox_v8_dynamic_import(v8::Local<v8::Context>, v8::Local<v8::Data>,
    v8::Local<v8::Value>, v8::Local<v8::String>, v8::Local<v8::FixedArray>);

namespace {

using v8::Context;
using v8::External;
using v8::Function;
using v8::FunctionCallbackInfo;
using v8::Global;
using v8::HandleScope;
using v8::Isolate;
using v8::Local;
using v8::MaybeLocal;
using v8::Object;
using v8::String;
using v8::TryCatch;
using v8::Value;

constexpr int kContextSlot = 2;  // Context embedder data: OpaqueJSContext*.
constexpr uint32_t kIsolateSlot = 3;  // Isolate data: Iso*.

struct Iso;
struct Box;

enum BoxKind : uint8_t { kUndefined, kNull, kTrue, kFalse, kNumber, kString, kSymbol, kBigInt, kObject };
enum BoxFlags : uint8_t {
    kFlagsKnown = 1, kFlagFunction = 2, kFlagArray = 4, kFlagConstructor = 8,
};
enum BoxTag : uint8_t { kTagNone, kTagModuleResolve };

struct Box {
    BoxKind kind;
    uint8_t flags = 0;
    BoxTag tag = kTagNone;
    bool in_turn = false;
    bool weak = false;
    bool registered = false;  // In iso->objects.
    uint32_t protects = 0;
    int hash = 0;
    double number = 0;
    Iso* iso = nullptr;
    Global<Value> handle;
    JSClassRef klass = nullptr;
    void* priv = nullptr;
    JSObjectCallAsFunctionCallback call = nullptr;
    Box* prev = nullptr;  // All boxes owning a V8 handle, per isolate.
    Box* next = nullptr;
    explicit Box(BoxKind k) : kind(k) {}
};

Box g_undefined(kUndefined);
Box g_null(kNull);
Box g_true(kTrue);
Box g_false(kFalse);

inline bool is_constant(const Box* box)
{
    return box == &g_undefined || box == &g_null || box == &g_true || box == &g_false;
}

struct Counters {
    std::atomic<uint64_t> boxes { 0 }, object_boxes { 0 }, object_hits { 0 }, freed { 0 },
        weakened { 0 }, collected { 0 }, turns { 0 }, max_turn { 0 }, foreign { 0 },
        calls { 0 }, callbacks { 0 }, evaluations { 0 }, modules { 0 };
};
Counters g_counters;
bool g_diagnostics = false;

class RunLoopTaskRunner;

struct Iso {
    std::atomic<int> refs { 1 };
    Isolate* isolate = nullptr;
    pthread_t owner {};
    pthread_t last_thread {};
    std::vector<pthread_t> limited_threads;
    CFRunLoopRef loop = nullptr;
    CFRunLoopObserverRef observer = nullptr;
    std::shared_ptr<RunLoopTaskRunner> runner;
    std::vector<Box*> turn;
    std::mutex foreign_mutex;
    std::vector<Box*> foreign_turn;
    std::unordered_multimap<int, Box*> objects;
    Box* handles = nullptr;  // Intrusive list head.
    int host_depth = 0;
    uintptr_t outer_sp = 0;
    int contexts = 0;
};

}  // namespace

struct OpaqueJSContextGroup {
    Iso iso;
};

struct OpaqueJSContext {
    std::atomic<int> refs { 1 };
    Iso* iso = nullptr;
    Global<Context> context;
    Box* global = nullptr;
    Global<Function> date_constructor;
    Global<Function> error_constructor;
    Global<Function> deferred;
    Loader* loader = nullptr;
};

struct OpaqueJSClass {
    std::atomic<int> refs { 1 };
    JSClassDefinition definition;
    std::string name;
};

struct OpaqueJSString {
    std::atomic<int> refs { 1 };
    size_t length = 0;
    JSChar* characters = nullptr;
};

namespace {

// ---------------------------------------------------------------------------
// Platform: V8 worker threads come from the default platform. Foreground tasks
// for an isolate run on its thread's CFRunLoop, which is Vox's event loop on the
// main thread and on worker threads.

Iso* iso_of(Isolate* isolate)
{
    return isolate ? static_cast<Iso*>(isolate->GetData(kIsolateSlot)) : nullptr;
}

void set_stack_limit(Isolate* isolate)
{
    pthread_t self = pthread_self();
    uintptr_t top = reinterpret_cast<uintptr_t>(pthread_get_stackaddr_np(self));
    size_t size = pthread_get_stacksize_np(self);
    if (!top || size < 256 * 1024) return;
    size_t reserve = std::max<size_t>(192 * 1024, size / 16);
    isolate->SetStackLimit(top - size + reserve);
}

// Run-loop observers and sources at the outermost loop level run at nearly the
// same stack depth; a loop pumped from inside V or script frames runs deeper.
constexpr uintptr_t kNestedStackMargin = 8192;

bool nested_run_loop(Iso* iso)
{
    uintptr_t sp = reinterpret_cast<uintptr_t>(__builtin_frame_address(0));
    return iso->host_depth > 0 || (iso->outer_sp && sp + kNestedStackMargin < iso->outer_sp);
}

class RunLoopTaskRunner final : public v8::TaskRunner, public std::enable_shared_from_this<RunLoopTaskRunner> {
public:
    RunLoopTaskRunner(Iso* iso, CFRunLoopRef loop)
        : iso_(iso)
        , loop_(loop)
    {
        CFRetain(loop_);
        CFRunLoopSourceContext context {};
        context.info = this;
        context.perform = [](void* info) { static_cast<RunLoopTaskRunner*>(info)->Perform(); };
        source_ = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
        CFRunLoopAddSource(loop_, source_, kCFRunLoopCommonModes);
        CFRunLoopTimerContext timer_context {};
        timer_context.info = this;
        timer_ = CFRunLoopTimerCreate(kCFAllocatorDefault, 1e18, 1e18, 0, 0,
            [](CFRunLoopTimerRef, void* info) { static_cast<RunLoopTaskRunner*>(info)->Perform(); },
            &timer_context);
        CFRunLoopAddTimer(loop_, timer_, kCFRunLoopCommonModes);
    }

    ~RunLoopTaskRunner() override
    {
        if (source_) CFRelease(source_);
        if (timer_) CFRelease(timer_);
        CFRelease(loop_);
    }

    // Called on the owning thread before the isolate is disposed.
    void Detach()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        iso_ = nullptr;
        CFRunLoopSourceInvalidate(source_);
        CFRunLoopTimerInvalidate(timer_);
        tasks_.clear();
        while (!delayed_.empty()) delayed_.pop();
    }

    bool IdleTasksEnabled() override { return false; }
    bool NonNestableTasksEnabled() const override { return true; }
    bool NonNestableDelayedTasksEnabled() const override { return true; }

protected:
    void PostTaskImpl(std::unique_ptr<v8::Task> task, const v8::SourceLocation&) override { Post(std::move(task)); }
    void PostNonNestableTaskImpl(std::unique_ptr<v8::Task> task, const v8::SourceLocation&) override { Post(std::move(task)); }
    void PostDelayedTaskImpl(std::unique_ptr<v8::Task> task, double delay, const v8::SourceLocation&) override
    {
        PostDelayed(std::move(task), delay);
    }
    void PostNonNestableDelayedTaskImpl(std::unique_ptr<v8::Task> task, double delay, const v8::SourceLocation&) override
    {
        PostDelayed(std::move(task), delay);
    }
    void PostIdleTaskImpl(std::unique_ptr<v8::IdleTask>, const v8::SourceLocation&) override { }

private:
    struct Delayed {
        double due;
        uint64_t sequence;
        mutable std::unique_ptr<v8::Task> task;
        bool operator<(const Delayed& other) const
        {
            return due == other.due ? sequence > other.sequence : due > other.due;
        }
    };

    void Post(std::unique_ptr<v8::Task> task)
    {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (!iso_) return;
            tasks_.push_back(std::move(task));
        }
        CFRunLoopSourceSignal(source_);
        CFRunLoopWakeUp(loop_);
    }

    void PostDelayed(std::unique_ptr<v8::Task> task, double delay)
    {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (!iso_) return;
            delayed_.push(Delayed { CFAbsoluteTimeGetCurrent() + std::max(0.0, delay), ++sequence_, std::move(task) });
        }
        // Re-arm the timer from the owning thread.
        CFRunLoopSourceSignal(source_);
        CFRunLoopWakeUp(loop_);
    }

    void Perform()
    {
        std::vector<std::unique_ptr<v8::Task>> ready;
        Iso* iso;
        double next_due = 0;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            iso = iso_;
            if (!iso) return;
            // Vox pumps the run loop inside layout and navigation work, and
            // nested loops can run while a host callback is active. Tasks may
            // run script, so they wait for the outermost loop level.
            if (nested_run_loop(iso)) {
                CFRunLoopTimerSetNextFireDate(timer_, CFAbsoluteTimeGetCurrent() + 0.004);
                return;
            }
            double now = CFAbsoluteTimeGetCurrent();
            while (!delayed_.empty() && delayed_.top().due <= now) {
                ready.push_back(std::move(delayed_.top().task));
                delayed_.pop();
            }
            for (auto& task : tasks_) ready.push_back(std::move(task));
            tasks_.clear();
            if (!delayed_.empty()) next_due = delayed_.top().due;
        }
        CFRunLoopTimerSetNextFireDate(timer_, next_due ? next_due : 1e18);
        if (ready.empty()) return;
        auto keep = shared_from_this();
        Isolate* isolate = iso->isolate;
        v8::Locker locker(isolate);
        Isolate::Scope isolate_scope(isolate);
        for (auto& task : ready) {
            {
                std::lock_guard<std::mutex> lock(mutex_);
                if (!iso_) return;
            }
            HandleScope scope(isolate);
            task->Run();
        }
        if (iso->host_depth == 0) isolate->PerformMicrotaskCheckpoint();
    }

    std::mutex mutex_;
    Iso* iso_;
    CFRunLoopRef loop_;
    CFRunLoopSourceRef source_ = nullptr;
    CFRunLoopTimerRef timer_ = nullptr;
    std::deque<std::unique_ptr<v8::Task>> tasks_;
    std::priority_queue<Delayed> delayed_;
    uint64_t sequence_ = 0;
};

class VoxPlatform final : public v8::Platform {
public:
    explicit VoxPlatform(std::unique_ptr<v8::Platform> base)
        : base_(std::move(base))
    {
    }
    v8::PageAllocator* GetPageAllocator() override { return base_->GetPageAllocator(); }
    void OnCriticalMemoryPressure() override { base_->OnCriticalMemoryPressure(); }
    int NumberOfWorkerThreads() override { return base_->NumberOfWorkerThreads(); }
    std::shared_ptr<v8::TaskRunner> GetForegroundTaskRunner(Isolate* isolate, v8::TaskPriority) override
    {
        Iso* iso = iso_of(isolate);
        if (iso && iso->runner) return iso->runner;
        return base_->GetForegroundTaskRunner(isolate);
    }
    bool IdleTasksEnabled(Isolate*) override { return false; }
    double MonotonicallyIncreasingTime() override { return base_->MonotonicallyIncreasingTime(); }
    double CurrentClockTimeMillis() override { return base_->CurrentClockTimeMillis(); }
    v8::TracingController* GetTracingController() override { return base_->GetTracingController(); }

protected:
    std::unique_ptr<v8::JobHandle> CreateJobImpl(v8::TaskPriority priority, std::unique_ptr<v8::JobTask> task,
        const v8::SourceLocation& location) override
    {
        return base_->CreateJob(priority, std::move(task), location);
    }
    void PostTaskOnWorkerThreadImpl(v8::TaskPriority priority, std::unique_ptr<v8::Task> task,
        const v8::SourceLocation& location) override
    {
        base_->PostTaskOnWorkerThread(priority, std::move(task), location);
    }
    void PostDelayedTaskOnWorkerThreadImpl(v8::TaskPriority priority, std::unique_ptr<v8::Task> task,
        double delay, const v8::SourceLocation& location) override
    {
        base_->PostDelayedTaskOnWorkerThread(priority, std::move(task), delay, location);
    }

private:
    std::unique_ptr<v8::Platform> base_;
};

pthread_once_t g_platform_once = PTHREAD_ONCE_INIT;
VoxPlatform* g_platform = nullptr;
v8::ArrayBuffer::Allocator* g_allocator = nullptr;

void print_counters()
{
    fprintf(stderr,
        "Vox V8 handles: boxes=%llu objects=%llu object_hits=%llu freed=%llu weakened=%llu collected=%llu "
        "turns=%llu max_turn=%llu foreign=%llu calls=%llu callbacks=%llu evaluations=%llu modules=%llu\n",
        (unsigned long long)g_counters.boxes, (unsigned long long)g_counters.object_boxes,
        (unsigned long long)g_counters.object_hits, (unsigned long long)g_counters.freed,
        (unsigned long long)g_counters.weakened, (unsigned long long)g_counters.collected,
        (unsigned long long)g_counters.turns, (unsigned long long)g_counters.max_turn,
        (unsigned long long)g_counters.foreign, (unsigned long long)g_counters.calls,
        (unsigned long long)g_counters.callbacks, (unsigned long long)g_counters.evaluations,
        (unsigned long long)g_counters.modules);
}

void initialize_platform()
{
    g_diagnostics = getenv("VOX_V8_DIAGNOSTICS") != nullptr;
    if (const char* flags = getenv("VOX_V8_FLAGS")) v8::V8::SetFlagsFromString(flags);
    v8::V8::InitializeICU();
    g_platform = new VoxPlatform(v8::platform::NewDefaultPlatform(0, v8::platform::IdleTaskSupport::kDisabled));
    v8::V8::InitializePlatform(g_platform);
    v8::V8::Initialize();
    g_allocator = v8::ArrayBuffer::Allocator::NewDefaultAllocator();
    if (g_diagnostics) {
        fprintf(stderr, "Vox V8 backend: V8 %s\n", v8::V8::GetVersion());
        atexit(print_counters);
    }
}

// ---------------------------------------------------------------------------
// Isolate entry.

void note_thread(Iso* iso)
{
    pthread_t self = pthread_self();
    if (pthread_equal(self, iso->last_thread)) return;
    iso->last_thread = self;
    for (pthread_t thread : iso->limited_threads)
        if (pthread_equal(thread, self)) return;
    iso->limited_threads.push_back(self);
    set_stack_limit(iso->isolate);
}

struct IsolateEntry {
    v8::Locker locker;
    Isolate::Scope isolate_scope;
    HandleScope handles;
    explicit IsolateEntry(Iso* iso)
        : locker(iso->isolate)
        , isolate_scope(iso->isolate)
        , handles(iso->isolate)
    {
        note_thread(iso);
    }
};

struct Entry {
    Iso* iso;
    Isolate* isolate;
    IsolateEntry entry;
    Local<Context> context;
    Context::Scope context_scope;
    explicit Entry(JSContextRef ref)
        : iso(ref->iso)
        , isolate(iso->isolate)
        , entry(iso)
        , context(ref->context.Get(isolate))
        , context_scope(context)
    {
    }
    // JSC drains microtasks when the outermost API entry releases its lock.
    ~Entry()
    {
        if (iso->host_depth == 0 && !isolate->IsExecutionTerminating()) isolate->PerformMicrotaskCheckpoint();
    }
};

JSContextRef context_of(Local<Context> context)
{
    if (context.IsEmpty()) return nullptr;
    return static_cast<JSContextRef>(context->GetAlignedPointerFromEmbedderData(kContextSlot));
}

// ---------------------------------------------------------------------------
// Boxes.

void link_handle(Iso* iso, Box* box)
{
    box->next = iso->handles;
    if (iso->handles) iso->handles->prev = box;
    iso->handles = box;
}

void unlink_handle(Iso* iso, Box* box)
{
    if (box->prev) box->prev->next = box->next;
    else if (iso->handles == box) iso->handles = box->next;
    if (box->next) box->next->prev = box->prev;
    box->prev = box->next = nullptr;
}

void unregister_object(Box* box)
{
    if (!box->registered) return;
    auto range = box->iso->objects.equal_range(box->hash);
    for (auto it = range.first; it != range.second; ++it) {
        if (it->second == box) {
            box->iso->objects.erase(it);
            break;
        }
    }
    box->registered = false;
}

void free_box(Box* box)
{
    if (is_constant(box)) return;
    Iso* iso = box->iso;
    unregister_object(box);
    if (!box->handle.IsEmpty() || box->prev || box->next || iso->handles == box) unlink_handle(iso, box);
    box->handle.Reset();
    if (box->klass) JSClassRelease(box->klass);
    ++g_counters.freed;
    delete box;
}

void add_to_turn(Box* box)
{
    if (box->in_turn) return;
    Iso* iso = box->iso;
    box->in_turn = true;
    if (pthread_equal(pthread_self(), iso->owner)) {
        iso->turn.push_back(box);
    } else {
        // No observer runs on this thread; keep its temporaries alive.
        std::lock_guard<std::mutex> lock(iso->foreign_mutex);
        iso->foreign_turn.push_back(box);
        ++g_counters.foreign;
    }
}

void finalize_second_pass(const v8::WeakCallbackInfo<Box>& info)
{
    Box* box = info.GetParameter();
    if (box->klass && box->klass->definition.finalize) box->klass->definition.finalize(reinterpret_cast<JSObjectRef>(box));
    free_box(box);
}

void weak_callback(const v8::WeakCallbackInfo<Box>& info)
{
    Box* box = info.GetParameter();
    box->handle.Reset();
    unregister_object(box);
    unlink_handle(box->iso, box);
    ++g_counters.collected;
    if (box->klass && box->klass->definition.finalize) {
        info.SetSecondPassCallback(finalize_second_pass);
        return;
    }
    free_box(box);
}

void make_weak(Box* box)
{
    if (box->weak || box->handle.IsEmpty()) return;
    box->weak = true;
    box->handle.SetWeak(box, weak_callback, v8::WeakCallbackType::kParameter);
    ++g_counters.weakened;
}

void make_strong(Box* box)
{
    if (!box->weak) return;
    box->weak = false;
    box->handle.ClearWeak<Box>();
}

void release_after_turn(Box* box)
{
    box->in_turn = false;
    if (box->protects) return;
    if (box->kind == kObject) make_weak(box);
    else free_box(box);
}

void end_turn(Iso* iso)
{
    if (iso->turn.empty()) return;
    ++g_counters.turns;
    if (iso->turn.size() > g_counters.max_turn) g_counters.max_turn = iso->turn.size();
    std::vector<Box*> turn;
    turn.swap(iso->turn);
    for (Box* box : turn) release_after_turn(box);
}

Box* new_box(Iso* iso, BoxKind kind)
{
    Box* box = new Box(kind);
    box->iso = iso;
    ++g_counters.boxes;
    return box;
}

Box* wrap_object(Iso* iso, Local<Object> object)
{
    Isolate* isolate = iso->isolate;
    int hash = object->GetIdentityHash();
    auto range = iso->objects.equal_range(hash);
    for (auto it = range.first; it != range.second; ++it) {
        Box* box = it->second;
        if (!box->handle.IsEmpty() && box->handle == object) {
            make_strong(box);
            add_to_turn(box);
            ++g_counters.object_hits;
            return box;
        }
    }
    Box* box = new_box(iso, kObject);
    box->hash = hash;
    box->handle.Reset(isolate, object);
    link_handle(iso, box);
    iso->objects.emplace(hash, box);
    box->registered = true;
    add_to_turn(box);
    ++g_counters.object_boxes;
    return box;
}

Box* wrap(Iso* iso, Local<Value> value)
{
    if (value.IsEmpty()) return nullptr;
    if (value->IsUndefined()) return &g_undefined;
    if (value->IsNull()) return &g_null;
    if (value->IsTrue()) return &g_true;
    if (value->IsFalse()) return &g_false;
    if (value->IsNumber()) {
        Box* box = new_box(iso, kNumber);
        box->number = value.As<v8::Number>()->Value();
        add_to_turn(box);
        return box;
    }
    if (value->IsObject()) return wrap_object(iso, value.As<Object>());
    BoxKind kind = value->IsString() ? kString : value->IsSymbol() ? kSymbol : kBigInt;
    Box* box = new_box(iso, kind);
    box->handle.Reset(iso->isolate, value);
    link_handle(iso, box);
    add_to_turn(box);
    return box;
}

inline JSValueRef ref(Box* box) { return reinterpret_cast<JSValueRef>(box); }
inline JSObjectRef object_ref(Box* box) { return reinterpret_cast<JSObjectRef>(box); }
inline Box* box_of(JSValueRef value) { return reinterpret_cast<Box*>(const_cast<OpaqueJSValue*>(value)); }

Local<Value> unwrap(Isolate* isolate, JSValueRef value)
{
    Box* box = box_of(value);
    if (!box) return v8::Undefined(isolate);
    switch (box->kind) {
    case kUndefined: return v8::Undefined(isolate);
    case kNull: return v8::Null(isolate);
    case kTrue: return v8::True(isolate);
    case kFalse: return v8::False(isolate);
    case kNumber: return v8::Number::New(isolate, box->number);
    default:
        if (box->handle.IsEmpty()) return v8::Undefined(isolate);
        return box->handle.Get(isolate);
    }
}

bool unwrap_object(Isolate* isolate, JSValueRef value, Local<Object>* out)
{
    Box* box = box_of(value);
    if (!box || box->kind != kObject || box->handle.IsEmpty()) return false;
    *out = box->handle.Get(isolate).As<Object>();
    return true;
}

void store_exception(Iso* iso, TryCatch& try_catch, JSValueRef* exception)
{
    if (!try_catch.HasCaught()) return;
    if (exception) {
        Local<Value> value = try_catch.Exception();
        *exception = ref(wrap(iso, value.IsEmpty() ? v8::Undefined(iso->isolate).As<Value>() : value));
    }
}

void throw_type_error(Isolate* isolate, const char* message)
{
    isolate->ThrowException(v8::Exception::TypeError(String::NewFromUtf8(isolate, message).ToLocalChecked()));
}

uint8_t object_flags(Iso* iso, Box* box)
{
    if (box->flags & kFlagsKnown) return box->flags;
    IsolateEntry entry(iso);
    Local<Value> value = box->handle.Get(iso->isolate);
    uint8_t flags = kFlagsKnown;
    if (value->IsFunction()) {
        flags |= kFlagFunction;
        if (value.As<Object>()->IsConstructor()) flags |= kFlagConstructor;
    }
    if (value->IsArray()) flags |= kFlagArray;
    box->flags = flags;
    return flags;
}

// ---------------------------------------------------------------------------
// Strings.

JSStringRef new_string(size_t length)
{
    auto* string = static_cast<OpaqueJSString*>(malloc(sizeof(OpaqueJSString) + (length + 1) * sizeof(JSChar)));
    if (!string) abort();
    new (string) OpaqueJSString();
    string->length = length;
    string->characters = reinterpret_cast<JSChar*>(string + 1);
    string->characters[length] = 0;
    return string;
}

Local<String> v8_string(Isolate* isolate, JSStringRef string, v8::NewStringType type = v8::NewStringType::kNormal)
{
    if (!string || !string->length) return String::Empty(isolate);
    Local<String> result;
    if (!String::NewFromTwoByte(isolate, string->characters, type, static_cast<int>(string->length)).ToLocal(&result))
        return String::Empty(isolate);
    return result;
}

JSStringRef copy_v8_string(Isolate* isolate, Local<String> value)
{
    size_t length = value->Length();
    JSStringRef string = new_string(length);
    if (length) value->WriteV2(isolate, 0, static_cast<uint32_t>(length), string->characters);
    return string;
}

Local<String> utf8_string(Isolate* isolate, const char* bytes, size_t length = SIZE_MAX)
{
    if (!bytes) return String::Empty(isolate);
    if (length == SIZE_MAX) length = strlen(bytes);
    return String::NewFromUtf8(isolate, bytes, v8::NewStringType::kNormal, static_cast<int>(length)).ToLocalChecked();
}

// ---------------------------------------------------------------------------
// Context and isolate lifetime.

void observer_callback(CFRunLoopObserverRef, CFRunLoopActivity, void* info)
{
    Iso* iso = static_cast<Iso*>(info);
    uintptr_t sp = reinterpret_cast<uintptr_t>(__builtin_frame_address(0));
    if (sp > iso->outer_sp) iso->outer_sp = sp;
    // A nested run loop (document work, modal UI, synchronous waits) still has
    // callers that may hold temporaries. Only the outermost loop ends the turn.
    if (nested_run_loop(iso)) return;
    if (iso->turn.empty()) return;
    IsolateEntry entry(iso);
    end_turn(iso);
}

Iso* create_iso()
{
    pthread_once(&g_platform_once, initialize_platform);
    auto* group = new OpaqueJSContextGroup();
    Iso* iso = &group->iso;
    Isolate::CreateParams params;
    params.array_buffer_allocator = g_allocator;
    iso->isolate = Isolate::New(params);
    iso->isolate->SetData(kIsolateSlot, iso);
    iso->owner = pthread_self();
    iso->loop = CFRunLoopGetCurrent();
    CFRetain(iso->loop);
    iso->runner = std::make_shared<RunLoopTaskRunner>(iso, iso->loop);
    {
        IsolateEntry entry(iso);
        iso->isolate->SetFatalErrorHandler([](const char* location, const char* message) {
            fprintf(stderr, "Vox V8 fatal error in %s: %s\n", location ? location : "?", message ? message : "?");
            abort();
        });
        iso->isolate->SetMicrotasksPolicy(v8::MicrotasksPolicy::kAuto);
        iso->isolate->SetHostImportModuleDynamicallyCallback(vox_v8_dynamic_import);
    }
    CFRunLoopObserverContext context {};
    context.info = iso;
    iso->observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 1000000,
        observer_callback, &context);
    CFRunLoopAddObserver(iso->loop, iso->observer, kCFRunLoopCommonModes);
    return iso;
}

void dispose_iso(Iso* iso)
{
    if (iso->observer) {
        CFRunLoopObserverInvalidate(iso->observer);
        CFRelease(iso->observer);
    }
    iso->runner->Detach();
    {
        IsolateEntry entry(iso);
        // Run class finalizers, as JSC does when its VM is destroyed.
        std::vector<Box*> boxes;
        for (Box* box = iso->handles; box; box = box->next) boxes.push_back(box);
        for (Box* box : boxes) {
            if (box->kind == kObject && box->klass && box->klass->definition.finalize)
                box->klass->definition.finalize(object_ref(box));
        }
        for (Box* box : boxes) {
            box->handle.Reset();
            box->prev = box->next = nullptr;
            box->registered = false;
        }
        iso->handles = nullptr;
        iso->objects.clear();
        // Remaining boxes are invalid, as JSValueRefs of a destroyed JSC VM are.
        // Free those no longer referenced by any turn list.
        for (Box* box : iso->turn) box->in_turn = false;
        iso->turn.clear();
        for (Box* box : boxes) {
            if (box->klass) JSClassRelease(box->klass);
            box->klass = nullptr;
            delete box;
        }
    }
    iso->isolate->Dispose();
    CFRelease(iso->loop);
    delete reinterpret_cast<OpaqueJSContextGroup*>(iso);
}

void release_iso(Iso* iso)
{
    if (--iso->refs == 0) dispose_iso(iso);
}

JSGlobalContextRef create_context(Iso* iso, JSClassRef global_class)
{
    auto* ctx = new OpaqueJSContext();
    ctx->iso = iso;
    ++iso->refs;
    ++iso->contexts;
    IsolateEntry entry(iso);
    Isolate* isolate = iso->isolate;
    Local<v8::ObjectTemplate> global_template;
    if (global_class && !global_class->name.empty()) {
        Local<v8::FunctionTemplate> constructor = v8::FunctionTemplate::New(isolate);
        constructor->SetClassName(utf8_string(isolate, global_class->name.c_str()));
        global_template = constructor->InstanceTemplate();
    }
    Local<Context> context = Context::New(isolate, nullptr, global_template);
    context->SetAlignedPointerInEmbedderData(kContextSlot, ctx);
    ctx->context.Reset(isolate, context);
    Context::Scope scope(context);
    Local<Object> global = context->Global();
    if (global_class && global_template.IsEmpty()) {
        // JSC gives a classed global object its own automatic prototype. A
        // named class gets one from its FunctionTemplate; add it otherwise.
        Local<Object> prototype = Object::New(isolate);
        (void)global->SetPrototypeV2(context, prototype);
    }
    // Capture intrinsics before author code can replace them.
    const char* intrinsics = "(function(){'use strict';const P=Promise;"
                             "return [Date,Error,function(){let a,b;const p=new P((x,y)=>{a=x;b=y;});return [p,a,b];}];})()";
    Local<v8::Script> script = v8::Script::Compile(context, utf8_string(isolate, intrinsics)).ToLocalChecked();
    Local<v8::Array> values = script->Run(context).ToLocalChecked().As<v8::Array>();
    ctx->date_constructor.Reset(isolate, values->Get(context, 0).ToLocalChecked().As<Function>());
    ctx->error_constructor.Reset(isolate, values->Get(context, 1).ToLocalChecked().As<Function>());
    ctx->deferred.Reset(isolate, values->Get(context, 2).ToLocalChecked().As<Function>());
    ctx->global = wrap(iso, global);
    ++ctx->global->protects;
    return ctx;
}

// ---------------------------------------------------------------------------
// Host functions.

void host_function_trampoline(const FunctionCallbackInfo<Value>& info)
{
    Box* self = static_cast<Box*>(info.Data().As<External>()->Value());
    Isolate* isolate = info.GetIsolate();
    Iso* iso = self->iso;
    JSContextRef ctx = context_of(isolate->GetCurrentContext());
    if (!ctx || !self->call) {
        throw_type_error(isolate, "Host function is unavailable");
        return;
    }
    ++g_counters.callbacks;
    make_strong(self);
    add_to_turn(self);
    int count = info.Length();
    JSValueRef inline_arguments[8];
    std::unique_ptr<JSValueRef[]> heap_arguments;
    JSValueRef* arguments = inline_arguments;
    if (count > 8) {
        heap_arguments.reset(new JSValueRef[count]);
        arguments = heap_arguments.get();
    }
    for (int i = 0; i < count; ++i) arguments[i] = ref(wrap(iso, info[i]));
    JSObjectRef receiver = object_ref(wrap(iso, info.This()));
    JSValueRef exception = nullptr;
    ++iso->host_depth;
    JSValueRef result = self->call(ctx, object_ref(self), receiver, static_cast<size_t>(count), arguments, &exception);
    --iso->host_depth;
    if (exception) {
        isolate->ThrowException(unwrap(isolate, exception));
        return;
    }
    if (result) info.GetReturnValue().Set(unwrap(isolate, result));
}

Box* make_host_function(Iso* iso, Local<Context> context, JSObjectCallAsFunctionCallback call, JSClassRef klass,
    void* data, Local<String> name)
{
    Isolate* isolate = iso->isolate;
    Box* box = new_box(iso, kObject);
    box->call = call;
    box->klass = klass ? JSClassRetain(klass) : nullptr;
    box->priv = data;
    Local<Function> function = Function::New(context, host_function_trampoline, External::New(isolate, box), 0,
        v8::ConstructorBehavior::kThrow)
                                   .ToLocalChecked();
    if (!name.IsEmpty()) function->SetName(name);
    box->hash = function->GetIdentityHash();
    box->handle.Reset(isolate, function);
    box->flags = kFlagsKnown | kFlagFunction;
    link_handle(iso, box);
    iso->objects.emplace(box->hash, box);
    box->registered = true;
    add_to_turn(box);
    ++g_counters.object_boxes;
    return box;
}

v8::PropertyAttribute property_attributes(JSPropertyAttributes attributes)
{
    int result = v8::None;
    if (attributes & kJSPropertyAttributeReadOnly) result |= v8::ReadOnly;
    if (attributes & kJSPropertyAttributeDontEnum) result |= v8::DontEnum;
    if (attributes & kJSPropertyAttributeDontDelete) result |= v8::DontDelete;
    return static_cast<v8::PropertyAttribute>(result);
}

Local<Value> make_typed_array(Isolate* isolate, JSTypedArrayType type, Local<v8::ArrayBuffer> buffer, size_t offset,
    size_t length)
{
    switch (type) {
    case kJSTypedArrayTypeInt8Array: return v8::Int8Array::New(buffer, offset, length);
    case kJSTypedArrayTypeInt16Array: return v8::Int16Array::New(buffer, offset, length);
    case kJSTypedArrayTypeInt32Array: return v8::Int32Array::New(buffer, offset, length);
    case kJSTypedArrayTypeUint8Array: return v8::Uint8Array::New(buffer, offset, length);
    case kJSTypedArrayTypeUint8ClampedArray: return v8::Uint8ClampedArray::New(buffer, offset, length);
    case kJSTypedArrayTypeUint16Array: return v8::Uint16Array::New(buffer, offset, length);
    case kJSTypedArrayTypeUint32Array: return v8::Uint32Array::New(buffer, offset, length);
    case kJSTypedArrayTypeFloat32Array: return v8::Float32Array::New(buffer, offset, length);
    case kJSTypedArrayTypeFloat64Array: return v8::Float64Array::New(buffer, offset, length);
    case kJSTypedArrayTypeBigInt64Array: return v8::BigInt64Array::New(buffer, offset, length);
    case kJSTypedArrayTypeBigUint64Array: return v8::BigUint64Array::New(buffer, offset, length);
    case kJSTypedArrayTypeArrayBuffer: return buffer;
    default: return Local<Value>();
    }
}

size_t element_size(JSTypedArrayType type)
{
    switch (type) {
    case kJSTypedArrayTypeInt16Array:
    case kJSTypedArrayTypeUint16Array: return 2;
    case kJSTypedArrayTypeInt32Array:
    case kJSTypedArrayTypeUint32Array:
    case kJSTypedArrayTypeFloat32Array: return 4;
    case kJSTypedArrayTypeFloat64Array:
    case kJSTypedArrayTypeBigInt64Array:
    case kJSTypedArrayTypeBigUint64Array: return 8;
    default: return 1;
    }
}

struct Deallocation {
    JSTypedArrayBytesDeallocator deallocator;
    void* context;
};

void deallocate_bytes(void* data, size_t, void* info)
{
    auto* deallocation = static_cast<Deallocation*>(info);
    if (deallocation->deallocator) deallocation->deallocator(data, deallocation->context);
    delete deallocation;
}

Local<v8::ArrayBuffer> external_buffer(Isolate* isolate, void* bytes, size_t length,
    JSTypedArrayBytesDeallocator deallocator, void* context)
{
    auto store = v8::ArrayBuffer::NewBackingStore(bytes, length, deallocate_bytes,
        new Deallocation { deallocator, context });
    return v8::ArrayBuffer::New(isolate, std::move(store));
}

bool view_of(Isolate* isolate, JSObjectRef object, Local<v8::ArrayBufferView>* view)
{
    Local<Object> value;
    if (!unwrap_object(isolate, object, &value) || !value->IsArrayBufferView()) return false;
    *view = value.As<v8::ArrayBufferView>();
    return true;
}

}  // namespace

// ===========================================================================
// JSBase.h

extern "C" JSValueRef JSEvaluateScript(JSContextRef ctx, JSStringRef script, JSObjectRef thisObject,
    JSStringRef sourceURL, int startingLineNumber, JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    ++g_counters.evaluations;
    TryCatch try_catch(e.isolate);
    Local<Value> name = sourceURL ? v8_string(e.isolate, sourceURL).As<Value>() : String::Empty(e.isolate).As<Value>();
    v8::ScriptOrigin origin(name, std::max(0, startingLineNumber - 1), 0);
    Local<String> source = v8_string(e.isolate, script);
    Local<Value> result;
    if (thisObject && thisObject != object_ref(ctx->global)) {
        // JSC binds |this| to thisObject. Run the script as a function body.
        v8::ScriptCompiler::Source function_source(source, origin);
        Local<Function> function;
        if (!v8::ScriptCompiler::CompileFunction(e.context, &function_source).ToLocal(&function)) {
            store_exception(e.iso, try_catch, exception);
            return nullptr;
        }
        if (!function->Call(e.context, unwrap(e.isolate, thisObject), 0, nullptr).ToLocal(&result)) {
            store_exception(e.iso, try_catch, exception);
            return nullptr;
        }
        return ref(wrap(e.iso, result));
    }
    v8::ScriptCompiler::Source compile_source(source, origin);
    Local<v8::Script> compiled;
    if (!v8::ScriptCompiler::Compile(e.context, &compile_source).ToLocal(&compiled)
        || !compiled->Run(e.context).ToLocal(&result)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return ref(wrap(e.iso, result));
}

extern "C" bool JSCheckScriptSyntax(JSContextRef ctx, JSStringRef script, JSStringRef sourceURL,
    int startingLineNumber, JSValueRef* exception)
{
    if (!ctx) return false;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Value> name = sourceURL ? v8_string(e.isolate, sourceURL).As<Value>() : String::Empty(e.isolate).As<Value>();
    v8::ScriptOrigin origin(name, std::max(0, startingLineNumber - 1), 0);
    v8::ScriptCompiler::Source source(v8_string(e.isolate, script), origin);
    Local<v8::UnboundScript> unbound;
    if (!v8::ScriptCompiler::CompileUnboundScript(e.isolate, &source).ToLocal(&unbound)) {
        store_exception(e.iso, try_catch, exception);
        return false;
    }
    return true;
}

extern "C" void JSGarbageCollect(JSContextRef ctx)
{
    // JSC treats this as a hint (reportAbandonedObjectGraph). Keep V8's own
    // heuristics unless a diagnostic run asks for an immediate collection.
    static bool force = getenv("VOX_V8_FORCE_GC_ON_HINT") != nullptr;
    if (!ctx || !force) return;
    IsolateEntry entry(ctx->iso);
    ctx->iso->isolate->LowMemoryNotification();
}

// ===========================================================================
// JSContextRef.h

extern "C" JSContextGroupRef JSContextGroupCreate(void)
{
    return reinterpret_cast<JSContextGroupRef>(create_iso());
}

extern "C" JSContextGroupRef JSContextGroupRetain(JSContextGroupRef group)
{
    if (group) ++const_cast<OpaqueJSContextGroup*>(group)->iso.refs;
    return group;
}

extern "C" void JSContextGroupRelease(JSContextGroupRef group)
{
    if (group) release_iso(&const_cast<OpaqueJSContextGroup*>(group)->iso);
}

extern "C" JSGlobalContextRef JSGlobalContextCreateInGroup(JSContextGroupRef group, JSClassRef globalObjectClass)
{
    if (!group) {
        Iso* iso = create_iso();
        JSGlobalContextRef ctx = create_context(iso, globalObjectClass);
        release_iso(iso);  // The context owns the group.
        return ctx;
    }
    return create_context(&const_cast<OpaqueJSContextGroup*>(group)->iso, globalObjectClass);
}

extern "C" JSGlobalContextRef JSGlobalContextCreate(JSClassRef globalObjectClass)
{
    return JSGlobalContextCreateInGroup(nullptr, globalObjectClass);
}

extern "C" JSGlobalContextRef JSGlobalContextRetain(JSGlobalContextRef ctx)
{
    if (ctx) ++ctx->refs;
    return ctx;
}

extern "C" void JSGlobalContextRelease(JSGlobalContextRef ctx)
{
    if (!ctx || --ctx->refs > 0) return;
    Iso* iso = ctx->iso;
    {
        IsolateEntry entry(iso);
        close_loader(ctx);
        {
            Local<Context> context = ctx->context.Get(iso->isolate);
            context->SetAlignedPointerInEmbedderData(kContextSlot, nullptr);
        }
        if (ctx->global && ctx->global->protects) {
            --ctx->global->protects;
            if (!ctx->global->in_turn) make_weak(ctx->global);
        }
        ctx->date_constructor.Reset();
        ctx->error_constructor.Reset();
        ctx->deferred.Reset();
        ctx->context.Reset();
        iso->isolate->ContextDisposedNotification();
    }
    --iso->contexts;
    delete ctx;
    release_iso(iso);
}

extern "C" JSObjectRef JSContextGetGlobalObject(JSContextRef ctx)
{
    return ctx ? object_ref(ctx->global) : nullptr;
}

extern "C" JSContextGroupRef JSContextGetGroup(JSContextRef ctx)
{
    return ctx ? reinterpret_cast<JSContextGroupRef>(ctx->iso) : nullptr;
}

extern "C" JSGlobalContextRef JSContextGetGlobalContext(JSContextRef ctx)
{
    return const_cast<JSGlobalContextRef>(ctx);
}

// ===========================================================================
// JSValueRef.h

extern "C" JSType JSValueGetType(JSContextRef, JSValueRef value)
{
    Box* box = box_of(value);
    if (!box) return kJSTypeUndefined;
    switch (box->kind) {
    case kUndefined: return kJSTypeUndefined;
    case kNull: return kJSTypeNull;
    case kTrue:
    case kFalse: return kJSTypeBoolean;
    case kNumber: return kJSTypeNumber;
    case kString: return kJSTypeString;
    case kSymbol: return kJSTypeSymbol;
    case kBigInt: return kJSTypeBigInt;
    case kObject: return kJSTypeObject;
    }
    return kJSTypeUndefined;
}

extern "C" bool JSValueIsUndefined(JSContextRef, JSValueRef value) { return value && box_of(value)->kind == kUndefined; }
extern "C" bool JSValueIsNull(JSContextRef, JSValueRef value) { return value && box_of(value)->kind == kNull; }
extern "C" bool JSValueIsBoolean(JSContextRef, JSValueRef value)
{
    return value && (box_of(value)->kind == kTrue || box_of(value)->kind == kFalse);
}
extern "C" bool JSValueIsNumber(JSContextRef, JSValueRef value) { return value && box_of(value)->kind == kNumber; }
extern "C" bool JSValueIsString(JSContextRef, JSValueRef value) { return value && box_of(value)->kind == kString; }
extern "C" bool JSValueIsSymbol(JSContextRef, JSValueRef value) { return value && box_of(value)->kind == kSymbol; }
extern "C" bool JSValueIsBigInt(JSContextRef, JSValueRef value) { return value && box_of(value)->kind == kBigInt; }
extern "C" bool JSValueIsObject(JSContextRef, JSValueRef value) { return value && box_of(value)->kind == kObject; }

extern "C" bool JSValueIsArray(JSContextRef ctx, JSValueRef value)
{
    Box* box = box_of(value);
    if (!ctx || !box || box->kind != kObject || box->handle.IsEmpty()) return false;
    return object_flags(ctx->iso, box) & kFlagArray;
}

extern "C" bool JSValueIsDate(JSContextRef ctx, JSValueRef value)
{
    Box* box = box_of(value);
    if (!ctx || !box || box->kind != kObject) return false;
    IsolateEntry entry(ctx->iso);
    return unwrap(ctx->iso->isolate, value)->IsDate();
}

extern "C" JSTypedArrayType JSValueGetTypedArrayType(JSContextRef ctx, JSValueRef value, JSValueRef*)
{
    Box* box = box_of(value);
    if (!ctx || !box || box->kind != kObject) return kJSTypedArrayTypeNone;
    IsolateEntry entry(ctx->iso);
    Local<Value> v = unwrap(ctx->iso->isolate, value);
    if (v->IsArrayBuffer() || v->IsSharedArrayBuffer()) return kJSTypedArrayTypeArrayBuffer;
    if (!v->IsTypedArray()) return kJSTypedArrayTypeNone;
    if (v->IsUint8Array()) return kJSTypedArrayTypeUint8Array;
    if (v->IsInt8Array()) return kJSTypedArrayTypeInt8Array;
    if (v->IsUint8ClampedArray()) return kJSTypedArrayTypeUint8ClampedArray;
    if (v->IsInt16Array()) return kJSTypedArrayTypeInt16Array;
    if (v->IsUint16Array()) return kJSTypedArrayTypeUint16Array;
    if (v->IsInt32Array()) return kJSTypedArrayTypeInt32Array;
    if (v->IsUint32Array()) return kJSTypedArrayTypeUint32Array;
    if (v->IsFloat32Array()) return kJSTypedArrayTypeFloat32Array;
    if (v->IsFloat64Array()) return kJSTypedArrayTypeFloat64Array;
    if (v->IsBigInt64Array()) return kJSTypedArrayTypeBigInt64Array;
    if (v->IsBigUint64Array()) return kJSTypedArrayTypeBigUint64Array;
    return kJSTypedArrayTypeNone;
}

extern "C" bool JSValueIsEqual(JSContextRef ctx, JSValueRef a, JSValueRef b, JSValueRef* exception)
{
    if (!ctx) return false;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    bool result = unwrap(e.isolate, a)->Equals(e.context, unwrap(e.isolate, b)).FromMaybe(false);
    store_exception(e.iso, try_catch, exception);
    return result;
}

extern "C" bool JSValueIsStrictEqual(JSContextRef ctx, JSValueRef a, JSValueRef b)
{
    Box* left = box_of(a);
    Box* right = box_of(b);
    if (!left || !right) return left == right;
    if (left->kind != right->kind) return false;
    switch (left->kind) {
    case kUndefined:
    case kNull:
    case kTrue:
    case kFalse: return true;
    case kNumber: return left->number == right->number;
    case kObject: return left == right;
    default:
        if (left == right) return true;
        if (!ctx) return false;
        IsolateEntry entry(ctx->iso);
        return unwrap(ctx->iso->isolate, a)->StrictEquals(unwrap(ctx->iso->isolate, b));
    }
}

extern "C" bool JSValueIsInstanceOfConstructor(JSContextRef ctx, JSValueRef value, JSObjectRef constructor,
    JSValueRef* exception)
{
    if (!ctx) return false;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Object> target;
    if (!unwrap_object(e.isolate, constructor, &target)) return false;
    bool result = unwrap(e.isolate, value)->InstanceOf(e.context, target).FromMaybe(false);
    store_exception(e.iso, try_catch, exception);
    return result;
}

extern "C" JSValueRef JSValueMakeUndefined(JSContextRef) { return ref(&g_undefined); }
extern "C" JSValueRef JSValueMakeNull(JSContextRef) { return ref(&g_null); }
extern "C" JSValueRef JSValueMakeBoolean(JSContextRef, bool value) { return ref(value ? &g_true : &g_false); }

extern "C" JSValueRef JSValueMakeNumber(JSContextRef ctx, double number)
{
    if (!ctx) return nullptr;
    Box* box = new_box(ctx->iso, kNumber);
    box->number = number;
    add_to_turn(box);
    return ref(box);
}

extern "C" JSValueRef JSValueMakeString(JSContextRef ctx, JSStringRef string)
{
    if (!ctx) return nullptr;
    IsolateEntry entry(ctx->iso);
    return ref(wrap(ctx->iso, v8_string(ctx->iso->isolate, string)));
}

extern "C" JSValueRef JSValueMakeSymbol(JSContextRef ctx, JSStringRef description)
{
    if (!ctx) return nullptr;
    IsolateEntry entry(ctx->iso);
    Isolate* isolate = ctx->iso->isolate;
    return ref(wrap(ctx->iso, v8::Symbol::New(isolate, description ? v8_string(isolate, description) : Local<String>())));
}

extern "C" JSValueRef JSValueMakeFromJSONString(JSContextRef ctx, JSStringRef string)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Value> result;
    if (!v8::JSON::Parse(e.context, v8_string(e.isolate, string)).ToLocal(&result)) return nullptr;
    return ref(wrap(e.iso, result));
}

extern "C" JSStringRef JSValueCreateJSONString(JSContextRef ctx, JSValueRef value, unsigned indent, JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    std::string gap(std::min(indent, 10u), ' ');
    Local<String> result;
    if (!v8::JSON::Stringify(e.context, unwrap(e.isolate, value), utf8_string(e.isolate, gap.c_str())).ToLocal(&result)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return copy_v8_string(e.isolate, result);
}

extern "C" bool JSValueToBoolean(JSContextRef ctx, JSValueRef value)
{
    Box* box = box_of(value);
    if (!box) return false;
    switch (box->kind) {
    case kUndefined:
    case kNull:
    case kFalse: return false;
    case kTrue: return true;
    case kNumber: return box->number != 0 && !std::isnan(box->number);
    case kObject:
    case kSymbol: return true;
    default: {
        if (!ctx) return false;
        IsolateEntry entry(ctx->iso);
        return unwrap(ctx->iso->isolate, value)->BooleanValue(ctx->iso->isolate);
    }
    }
}

extern "C" double JSValueToNumber(JSContextRef ctx, JSValueRef value, JSValueRef* exception)
{
    Box* box = box_of(value);
    if (!box) return NAN;
    switch (box->kind) {
    case kNumber: return box->number;
    case kUndefined: return NAN;
    case kNull:
    case kFalse: return 0;
    case kTrue: return 1;
    default: break;
    }
    if (!ctx) return NAN;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    double result = unwrap(e.isolate, value)->NumberValue(e.context).FromMaybe(NAN);
    store_exception(e.iso, try_catch, exception);
    return result;
}

extern "C" JSStringRef JSValueToStringCopy(JSContextRef ctx, JSValueRef value, JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Box* box = box_of(value);
    if (box && box->kind == kString) {
        IsolateEntry entry(ctx->iso);
        return copy_v8_string(ctx->iso->isolate, unwrap(ctx->iso->isolate, value).As<String>());
    }
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<String> result;
    if (!unwrap(e.isolate, value)->ToString(e.context).ToLocal(&result)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return copy_v8_string(e.isolate, result);
}

extern "C" JSObjectRef JSValueToObject(JSContextRef ctx, JSValueRef value, JSValueRef* exception)
{
    Box* box = box_of(value);
    if (box && box->kind == kObject) return object_ref(box);
    if (!ctx) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Object> result;
    if (!unwrap(e.isolate, value)->ToObject(e.context).ToLocal(&result)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return object_ref(wrap(e.iso, result));
}

extern "C" void JSValueProtect(JSContextRef, JSValueRef value)
{
    Box* box = box_of(value);
    if (!box || is_constant(box)) return;
    if (box->protects++ == 0 && box->weak) {
        IsolateEntry entry(box->iso);
        make_strong(box);
    }
}

extern "C" void JSValueUnprotect(JSContextRef, JSValueRef value)
{
    Box* box = box_of(value);
    if (!box || is_constant(box) || !box->protects) return;
    if (--box->protects == 0) {
        // Keep the value usable until the current turn ends, as a JSC value
        // remains valid at least while the caller's frame can still see it.
        if (!box->in_turn) {
            IsolateEntry entry(box->iso);
            add_to_turn(box);
        }
    }
}

// ===========================================================================
// JSObjectRef.h

extern "C" JSClassRef JSClassCreate(const JSClassDefinition* definition)
{
    auto* klass = new OpaqueJSClass();
    klass->definition = definition ? *definition : kJSClassDefinitionEmpty;
    if (klass->definition.className) klass->name = klass->definition.className;
    klass->definition.className = nullptr;
    return klass;
}

extern "C" JSClassRef JSClassRetain(JSClassRef klass)
{
    if (klass) ++klass->refs;
    return klass;
}

extern "C" void JSClassRelease(JSClassRef klass)
{
    if (klass && --klass->refs == 0) delete klass;
}

extern "C" JSObjectRef JSObjectMake(JSContextRef ctx, JSClassRef klass, void* data)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    if (klass && klass->definition.callAsFunction) {
        Box* box = make_host_function(e.iso, e.context, klass->definition.callAsFunction, klass, data,
            klass->name.empty() ? Local<String>() : utf8_string(e.isolate, klass->name.c_str()));
        if (klass->definition.initialize) klass->definition.initialize(ctx, object_ref(box));
        return object_ref(box);
    }
    Local<Object> object = Object::New(e.isolate);
    Box* box = wrap_object(e.iso, object);
    if (klass) {
        box->klass = JSClassRetain(klass);
        box->priv = data;
        if (klass->definition.initialize) klass->definition.initialize(ctx, object_ref(box));
    }
    return object_ref(box);
}

extern "C" JSObjectRef JSObjectMakeFunctionWithCallback(JSContextRef ctx, JSStringRef name,
    JSObjectCallAsFunctionCallback callAsFunction)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    Local<String> function_name = name ? v8_string(e.isolate, name) : utf8_string(e.isolate, "anonymous");
    return object_ref(make_host_function(e.iso, e.context, callAsFunction, nullptr, nullptr, function_name));
}

extern "C" JSObjectRef JSObjectMakeArray(JSContextRef ctx, size_t count, const JSValueRef arguments[],
    JSValueRef*)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    std::vector<Local<Value>> elements(count);
    for (size_t i = 0; i < count; ++i) elements[i] = unwrap(e.isolate, arguments[i]);
    return object_ref(wrap(e.iso, v8::Array::New(e.isolate, elements.data(), count)));
}

namespace {
JSObjectRef construct_intrinsic(JSContextRef ctx, const Global<Function>& constructor, size_t count,
    const JSValueRef arguments[], JSValueRef* exception)
{
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    std::vector<Local<Value>> values(count);
    for (size_t i = 0; i < count; ++i) values[i] = unwrap(e.isolate, arguments[i]);
    Local<Object> result;
    if (!constructor.Get(e.isolate)->NewInstance(e.context, static_cast<int>(count), values.data()).ToLocal(&result)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return object_ref(wrap(e.iso, result));
}
}  // namespace

extern "C" JSObjectRef JSObjectMakeDate(JSContextRef ctx, size_t count, const JSValueRef arguments[],
    JSValueRef* exception)
{
    if (!ctx) return nullptr;
    return construct_intrinsic(ctx, ctx->date_constructor, count, arguments, exception);
}

extern "C" JSObjectRef JSObjectMakeError(JSContextRef ctx, size_t count, const JSValueRef arguments[],
    JSValueRef* exception)
{
    if (!ctx) return nullptr;
    return construct_intrinsic(ctx, ctx->error_constructor, count, arguments, exception);
}

extern "C" JSObjectRef JSObjectMakeFunction(JSContextRef ctx, JSStringRef name, unsigned parameterCount,
    const JSStringRef parameterNames[], JSStringRef body, JSStringRef sourceURL, int startingLineNumber,
    JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Value> resource = sourceURL ? v8_string(e.isolate, sourceURL).As<Value>() : String::Empty(e.isolate).As<Value>();
    v8::ScriptOrigin origin(resource, std::max(0, startingLineNumber - 1), 0);
    v8::ScriptCompiler::Source source(v8_string(e.isolate, body), origin);
    std::vector<Local<String>> parameters(parameterCount);
    for (unsigned i = 0; i < parameterCount; ++i) parameters[i] = v8_string(e.isolate, parameterNames[i]);
    Local<Function> function;
    if (!v8::ScriptCompiler::CompileFunction(e.context, &source, parameterCount, parameters.data())
             .ToLocal(&function)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    function->SetName(name ? v8_string(e.isolate, name) : utf8_string(e.isolate, "anonymous"));
    return object_ref(wrap(e.iso, function));
}

extern "C" JSObjectRef JSObjectMakeDeferredPromise(JSContextRef ctx, JSObjectRef* resolve, JSObjectRef* reject,
    JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Value> result;
    if (!ctx->deferred.Get(e.isolate)->Call(e.context, v8::Undefined(e.isolate), 0, nullptr).ToLocal(&result)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    Local<v8::Array> parts = result.As<v8::Array>();
    if (resolve) *resolve = object_ref(wrap(e.iso, parts->Get(e.context, 1).ToLocalChecked()));
    if (reject) *reject = object_ref(wrap(e.iso, parts->Get(e.context, 2).ToLocalChecked()));
    return object_ref(wrap(e.iso, parts->Get(e.context, 0).ToLocalChecked()));
}

extern "C" JSValueRef JSObjectGetPrototype(JSContextRef ctx, JSObjectRef object)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    Local<Object> target;
    if (!unwrap_object(e.isolate, object, &target)) return ref(&g_null);
    return ref(wrap(e.iso, target->GetPrototypeV2()));
}

extern "C" void JSObjectSetPrototype(JSContextRef ctx, JSObjectRef object, JSValueRef value)
{
    if (!ctx) return;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Object> target;
    if (!unwrap_object(e.isolate, object, &target)) return;
    Local<Value> prototype = unwrap(e.isolate, value);
    if (!prototype->IsObject() && !prototype->IsNull()) return;
    (void)target->SetPrototypeV2(e.context, prototype);
}

extern "C" bool JSObjectHasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName)
{
    if (!ctx) return false;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Object> target;
    if (!unwrap_object(e.isolate, object, &target)) return false;
    return target->Has(e.context, v8_string(e.isolate, propertyName, v8::NewStringType::kInternalized)).FromMaybe(false);
}

extern "C" JSValueRef JSObjectGetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName,
    JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Object> target;
    if (!unwrap_object(e.isolate, object, &target)) return ref(&g_undefined);
    Local<Value> result;
    if (!target->Get(e.context, v8_string(e.isolate, propertyName, v8::NewStringType::kInternalized)).ToLocal(&result)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return ref(wrap(e.iso, result));
}

extern "C" void JSObjectSetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName,
    JSValueRef value, JSPropertyAttributes attributes, JSValueRef* exception)
{
    if (!ctx) return;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Object> target;
    if (!unwrap_object(e.isolate, object, &target)) return;
    Local<String> key = v8_string(e.isolate, propertyName, v8::NewStringType::kInternalized);
    Local<Value> v = unwrap(e.isolate, value);
    if (attributes && !target->Has(e.context, key).FromMaybe(true)) {
        if (!try_catch.HasCaught()) (void)target->DefineOwnProperty(e.context, key, v, property_attributes(attributes));
    } else if (!try_catch.HasCaught()) {
        (void)target->Set(e.context, key, v);
    }
    store_exception(e.iso, try_catch, exception);
}

extern "C" bool JSObjectDeleteProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName,
    JSValueRef* exception)
{
    if (!ctx) return false;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Object> target;
    if (!unwrap_object(e.isolate, object, &target)) return false;
    bool result = target->Delete(e.context, v8_string(e.isolate, propertyName, v8::NewStringType::kInternalized))
                      .FromMaybe(false);
    store_exception(e.iso, try_catch, exception);
    return result;
}

extern "C" JSValueRef JSObjectGetPropertyAtIndex(JSContextRef ctx, JSObjectRef object, unsigned index,
    JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Object> target;
    if (!unwrap_object(e.isolate, object, &target)) return ref(&g_undefined);
    Local<Value> result;
    if (!target->Get(e.context, index).ToLocal(&result)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return ref(wrap(e.iso, result));
}

extern "C" void JSObjectSetPropertyAtIndex(JSContextRef ctx, JSObjectRef object, unsigned index, JSValueRef value,
    JSValueRef* exception)
{
    if (!ctx) return;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Object> target;
    if (!unwrap_object(e.isolate, object, &target)) return;
    (void)target->Set(e.context, index, unwrap(e.isolate, value));
    store_exception(e.iso, try_catch, exception);
}

extern "C" void* JSObjectGetPrivate(JSObjectRef object)
{
    Box* box = box_of(object);
    return box && box->kind == kObject && box->tag == kTagNone ? box->priv : nullptr;
}

extern "C" bool JSObjectSetPrivate(JSObjectRef object, void* data)
{
    Box* box = box_of(object);
    if (!box || box->kind != kObject || !box->klass) return false;
    box->priv = data;
    return true;
}

extern "C" bool JSObjectIsFunction(JSContextRef ctx, JSObjectRef object)
{
    Box* box = box_of(object);
    if (!ctx || !box || box->kind != kObject || box->handle.IsEmpty()) return false;
    return object_flags(ctx->iso, box) & kFlagFunction;
}

extern "C" bool JSObjectIsConstructor(JSContextRef ctx, JSObjectRef object)
{
    Box* box = box_of(object);
    if (!ctx || !box || box->kind != kObject || box->handle.IsEmpty()) return false;
    return object_flags(ctx->iso, box) & kFlagConstructor;
}

extern "C" JSValueRef JSObjectCallAsFunction(JSContextRef ctx, JSObjectRef object, JSObjectRef thisObject,
    size_t count, const JSValueRef arguments[], JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    ++g_counters.calls;
    Local<Object> target;
    if (!unwrap_object(e.isolate, object, &target) || !target->IsFunction()) return nullptr;
    TryCatch try_catch(e.isolate);
    Local<Value> inline_values[8];
    std::unique_ptr<Local<Value>[]> heap_values;
    Local<Value>* values = inline_values;
    if (count > 8) {
        heap_values.reset(new Local<Value>[count]);
        values = heap_values.get();
    }
    for (size_t i = 0; i < count; ++i) values[i] = unwrap(e.isolate, arguments[i]);
    Local<Value> receiver = thisObject ? unwrap(e.isolate, thisObject) : e.context->Global().As<Value>();
    Local<Value> result;
    if (!target.As<Function>()->Call(e.context, receiver, static_cast<int>(count), values).ToLocal(&result)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return ref(wrap(e.iso, result));
}

extern "C" JSObjectRef JSObjectCallAsConstructor(JSContextRef ctx, JSObjectRef object, size_t count,
    const JSValueRef arguments[], JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    Local<Object> target;
    if (!unwrap_object(e.isolate, object, &target) || !target->IsConstructor()) return nullptr;
    TryCatch try_catch(e.isolate);
    std::vector<Local<Value>> values(count);
    for (size_t i = 0; i < count; ++i) values[i] = unwrap(e.isolate, arguments[i]);
    Local<Object> result;
    if (!target.As<Function>()->NewInstance(e.context, static_cast<int>(count), values.data()).ToLocal(&result)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return object_ref(wrap(e.iso, result));
}

// ===========================================================================
// JSStringRef.h

extern "C" JSStringRef JSStringCreateWithCharacters(const JSChar* characters, size_t count)
{
    JSStringRef string = new_string(count);
    if (count && characters) memcpy(string->characters, characters, count * sizeof(JSChar));
    return string;
}

extern "C" JSStringRef JSStringCreateWithUTF8CString(const char* text)
{
    if (!text) return new_string(0);
    size_t length = strlen(text);
    std::vector<JSChar> units;
    units.reserve(length);
    const auto* bytes = reinterpret_cast<const unsigned char*>(text);
    for (size_t i = 0; i < length;) {
        uint32_t c = bytes[i];
        size_t extra = c < 0x80 ? 0 : (c >> 5) == 6 ? 1 : (c >> 4) == 14 ? 2 : (c >> 3) == 30 ? 3 : SIZE_MAX;
        if (extra == SIZE_MAX || i + extra >= length + (extra ? 0 : 1)) {
            units.push_back(0xFFFD);
            ++i;
            continue;
        }
        uint32_t code = extra == 0 ? c : extra == 1 ? c & 0x1F : extra == 2 ? c & 0x0F : c & 0x07;
        bool valid = true;
        for (size_t k = 1; k <= extra; ++k) {
            if ((bytes[i + k] & 0xC0) != 0x80) {
                valid = false;
                break;
            }
            code = (code << 6) | (bytes[i + k] & 0x3F);
        }
        if (!valid) {
            units.push_back(0xFFFD);
            ++i;
            continue;
        }
        i += extra + 1;
        if (code >= 0x10000) {
            code -= 0x10000;
            units.push_back(static_cast<JSChar>(0xD800 + (code >> 10)));
            units.push_back(static_cast<JSChar>(0xDC00 + (code & 0x3FF)));
        } else {
            units.push_back(static_cast<JSChar>(code));
        }
    }
    return JSStringCreateWithCharacters(units.data(), units.size());
}

extern "C" JSStringRef JSStringRetain(JSStringRef string)
{
    if (string) ++string->refs;
    return string;
}

extern "C" void JSStringRelease(JSStringRef string)
{
    if (string && --string->refs == 0) {
        string->~OpaqueJSString();
        free(string);
    }
}

extern "C" size_t JSStringGetLength(JSStringRef string) { return string ? string->length : 0; }
extern "C" const JSChar* JSStringGetCharactersPtr(JSStringRef string) { return string ? string->characters : nullptr; }
extern "C" size_t JSStringGetMaximumUTF8CStringSize(JSStringRef string) { return string ? string->length * 3 + 1 : 1; }

extern "C" size_t JSStringGetUTF8CString(JSStringRef string, char* buffer, size_t size)
{
    if (!string || !buffer || !size) return 0;
    size_t out = 0;
    const JSChar* units = string->characters;
    size_t length = string->length;
    for (size_t i = 0; i < length; ++i) {
        uint32_t code = units[i];
        if (code >= 0xD800 && code <= 0xDBFF && i + 1 < length && units[i + 1] >= 0xDC00 && units[i + 1] <= 0xDFFF) {
            code = 0x10000 + ((code - 0xD800) << 10) + (units[i + 1] - 0xDC00);
            ++i;
        } else if (code >= 0xD800 && code <= 0xDFFF) {
            // JSC's strict conversion stops at an unpaired surrogate.
            break;
        }
        char encoded[4];
        size_t n;
        if (code < 0x80) {
            encoded[0] = static_cast<char>(code);
            n = 1;
        } else if (code < 0x800) {
            encoded[0] = static_cast<char>(0xC0 | (code >> 6));
            encoded[1] = static_cast<char>(0x80 | (code & 0x3F));
            n = 2;
        } else if (code < 0x10000) {
            encoded[0] = static_cast<char>(0xE0 | (code >> 12));
            encoded[1] = static_cast<char>(0x80 | ((code >> 6) & 0x3F));
            encoded[2] = static_cast<char>(0x80 | (code & 0x3F));
            n = 3;
        } else {
            encoded[0] = static_cast<char>(0xF0 | (code >> 18));
            encoded[1] = static_cast<char>(0x80 | ((code >> 12) & 0x3F));
            encoded[2] = static_cast<char>(0x80 | ((code >> 6) & 0x3F));
            encoded[3] = static_cast<char>(0x80 | (code & 0x3F));
            n = 4;
        }
        if (out + n + 1 > size) break;
        memcpy(buffer + out, encoded, n);
        out += n;
    }
    buffer[out++] = 0;
    return out;
}

extern "C" bool JSStringIsEqual(JSStringRef a, JSStringRef b)
{
    size_t la = JSStringGetLength(a), lb = JSStringGetLength(b);
    return la == lb && (!la || !memcmp(a->characters, b->characters, la * sizeof(JSChar)));
}

extern "C" bool JSStringIsEqualToUTF8CString(JSStringRef a, const char* b)
{
    JSStringRef other = JSStringCreateWithUTF8CString(b);
    bool equal = JSStringIsEqual(a, other);
    JSStringRelease(other);
    return equal;
}

extern "C" JSStringRef JSStringCreateWithCFString(CFStringRef text)
{
    CFIndex length = text ? CFStringGetLength(text) : 0;
    JSStringRef string = new_string(static_cast<size_t>(length));
    if (length) CFStringGetCharacters(text, CFRangeMake(0, length), string->characters);
    return string;
}

extern "C" CFStringRef JSStringCopyCFString(CFAllocatorRef allocator, JSStringRef string)
{
    return CFStringCreateWithCharacters(allocator, string ? string->characters : nullptr,
        static_cast<CFIndex>(string ? string->length : 0));
}

// ===========================================================================
// JSTypedArray.h

extern "C" JSObjectRef JSObjectMakeTypedArray(JSContextRef ctx, JSTypedArrayType type, size_t length,
    JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    size_t bytes = length * element_size(type);
    Local<v8::ArrayBuffer> buffer = v8::ArrayBuffer::New(e.isolate, bytes);
    Local<Value> array = make_typed_array(e.isolate, type, buffer, 0, length);
    if (array.IsEmpty()) {
        throw_type_error(e.isolate, "Unsupported typed array type");
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return object_ref(wrap(e.iso, array));
}

extern "C" JSObjectRef JSObjectMakeTypedArrayWithBytesNoCopy(JSContextRef ctx, JSTypedArrayType type, void* bytes,
    size_t byteLength, JSTypedArrayBytesDeallocator deallocator, void* deallocatorContext, JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<v8::ArrayBuffer> buffer = external_buffer(e.isolate, bytes, byteLength, deallocator, deallocatorContext);
    Local<Value> array = make_typed_array(e.isolate, type, buffer, 0, byteLength / element_size(type));
    if (array.IsEmpty()) {
        throw_type_error(e.isolate, "Unsupported typed array type");
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    return object_ref(wrap(e.iso, array));
}

extern "C" JSObjectRef JSObjectMakeTypedArrayWithArrayBuffer(JSContextRef ctx, JSTypedArrayType type,
    JSObjectRef buffer, JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<Object> value;
    if (!unwrap_object(e.isolate, buffer, &value) || !value->IsArrayBuffer()) {
        throw_type_error(e.isolate, "Expected an ArrayBuffer");
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    Local<v8::ArrayBuffer> array_buffer = value.As<v8::ArrayBuffer>();
    Local<Value> array = make_typed_array(e.isolate, type, array_buffer, 0,
        array_buffer->ByteLength() / element_size(type));
    if (array.IsEmpty()) return nullptr;
    return object_ref(wrap(e.iso, array));
}

extern "C" void* JSObjectGetTypedArrayBytesPtr(JSContextRef ctx, JSObjectRef object, JSValueRef*)
{
    if (!ctx) return nullptr;
    IsolateEntry entry(ctx->iso);
    Local<v8::ArrayBufferView> view;
    if (!view_of(ctx->iso->isolate, object, &view)) return nullptr;
    // As in JSC, this is the start of the backing buffer; callers add the
    // view's byte offset themselves.
    return view->Buffer()->Data();
}

extern "C" size_t JSObjectGetTypedArrayLength(JSContextRef ctx, JSObjectRef object, JSValueRef*)
{
    if (!ctx) return 0;
    IsolateEntry entry(ctx->iso);
    Local<v8::ArrayBufferView> view;
    if (!view_of(ctx->iso->isolate, object, &view)) return 0;
    return view->IsTypedArray() ? view.As<v8::TypedArray>()->Length() : view->ByteLength();
}

extern "C" size_t JSObjectGetTypedArrayByteLength(JSContextRef ctx, JSObjectRef object, JSValueRef*)
{
    if (!ctx) return 0;
    IsolateEntry entry(ctx->iso);
    Local<v8::ArrayBufferView> view;
    return view_of(ctx->iso->isolate, object, &view) ? view->ByteLength() : 0;
}

extern "C" size_t JSObjectGetTypedArrayByteOffset(JSContextRef ctx, JSObjectRef object, JSValueRef*)
{
    if (!ctx) return 0;
    IsolateEntry entry(ctx->iso);
    Local<v8::ArrayBufferView> view;
    return view_of(ctx->iso->isolate, object, &view) ? view->ByteOffset() : 0;
}

extern "C" JSObjectRef JSObjectGetTypedArrayBuffer(JSContextRef ctx, JSObjectRef object, JSValueRef*)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    Local<v8::ArrayBufferView> view;
    if (!view_of(e.isolate, object, &view)) return nullptr;
    return object_ref(wrap(e.iso, view->Buffer()));
}

extern "C" JSObjectRef JSObjectMakeArrayBufferWithBytesNoCopy(JSContextRef ctx, void* bytes, size_t byteLength,
    JSTypedArrayBytesDeallocator deallocator, void* deallocatorContext, JSValueRef*)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    return object_ref(wrap(e.iso, external_buffer(e.isolate, bytes, byteLength, deallocator, deallocatorContext)));
}

extern "C" void* JSObjectGetArrayBufferBytesPtr(JSContextRef ctx, JSObjectRef object, JSValueRef*)
{
    if (!ctx) return nullptr;
    IsolateEntry entry(ctx->iso);
    Local<Object> value;
    if (!unwrap_object(ctx->iso->isolate, object, &value)) return nullptr;
    if (value->IsArrayBuffer()) return value.As<v8::ArrayBuffer>()->Data();
    if (value->IsSharedArrayBuffer()) return value.As<v8::SharedArrayBuffer>()->Data();
    return nullptr;
}

extern "C" size_t JSObjectGetArrayBufferByteLength(JSContextRef ctx, JSObjectRef object, JSValueRef*)
{
    if (!ctx) return 0;
    IsolateEntry entry(ctx->iso);
    Local<Object> value;
    if (!unwrap_object(ctx->iso->isolate, object, &value)) return 0;
    if (value->IsArrayBuffer()) return value.As<v8::ArrayBuffer>()->ByteLength();
    if (value->IsSharedArrayBuffer()) return value.As<v8::SharedArrayBuffer>()->ByteLength();
    return 0;
}

// ===========================================================================
// Vox extensions.

extern "C" const char* VoxJavaScriptEngineName(void) { return "v8"; }
extern "C" const char* VoxJavaScriptEngineVersion(void) { return v8::V8::GetVersion(); }

extern "C" void VoxJavaScriptEndTurn(JSContextRef ctx)
{
    if (!ctx || ctx->iso->host_depth > 0) return;
    IsolateEntry entry(ctx->iso);
    end_turn(ctx->iso);
}

// ===========================================================================
// Module loader (replaces module_loader_darwin.m's JSScript/delegate SPI).
//
// The V ModuleHost supplies sources through fetch(identifier, resolve, reject).
// Its transform already rewrites static specifiers to absolute URLs and dynamic
// imports to native import() of an absolute URL, so this loader keeps a module
// map per realm, fetches each dependency once, then links and evaluates.

namespace {

struct Graph;

struct ModuleRecord {
    Loader* loader = nullptr;
    std::string url;
    enum State { kFetching, kCompiled, kFailed } state = kFetching;
    Global<v8::Module> module;
    Global<Value> error;
    std::vector<std::string> dependencies;
    std::vector<std::shared_ptr<Graph>> waiters;
};

struct Graph {
    std::string root;
    Global<v8::Promise::Resolver> resolver;
    bool dynamic = false;
    bool failed = false;
    bool done = false;
    int pending = 0;
    std::unordered_set<std::string> seen;
};

}  // namespace

struct Loader {
    JSGlobalContextRef ctx = nullptr;
    Global<Function> fetch;
    void* owner = nullptr;
    VoxModuleEvaluationCallback evaluated = nullptr;
    bool closed = false;
    std::unordered_map<std::string, ModuleRecord*> records;
    std::unordered_map<int, ModuleRecord*> by_script;
};

namespace {

std::string utf8_of(Isolate* isolate, Local<Value> value)
{
    String::Utf8Value text(isolate, value);
    return *text ? std::string(*text, text.length()) : std::string();
}

std::string resolve_url(const std::string& specifier, const std::string& base)
{
    // Rewritten sources use absolute URLs. Keep a relative fallback for
    // sources the lexer could not rewrite.
    CFURLRef base_url = nullptr;
    if (!base.empty()) {
        base_url = CFURLCreateWithBytes(kCFAllocatorDefault, reinterpret_cast<const UInt8*>(base.data()),
            static_cast<CFIndex>(base.size()), kCFStringEncodingUTF8, nullptr);
    }
    CFURLRef url = CFURLCreateWithBytes(kCFAllocatorDefault, reinterpret_cast<const UInt8*>(specifier.data()),
        static_cast<CFIndex>(specifier.size()), kCFStringEncodingUTF8, base_url);
    std::string result = specifier;
    if (url) {
        CFURLRef absolute = CFURLCopyAbsoluteURL(url);
        if (absolute) {
            CFStringRef text = CFURLGetString(absolute);
            char buffer[8192];
            if (CFStringGetCString(text, buffer, sizeof(buffer), kCFStringEncodingUTF8)) result = buffer;
            CFRelease(absolute);
        }
        CFRelease(url);
    }
    if (base_url) CFRelease(base_url);
    return result;
}

bool is_absolute_url(const std::string& specifier)
{
    size_t colon = specifier.find(':');
    if (colon == std::string::npos || colon == 0) return false;
    for (size_t i = 0; i < colon; ++i) {
        char c = specifier[i];
        if (!(isalnum(static_cast<unsigned char>(c)) || c == '+' || c == '-' || c == '.')) return false;
    }
    return true;
}

void graph_load(Loader* loader, const std::shared_ptr<Graph>& graph, const std::string& url);
void graph_check(Loader* loader, const std::shared_ptr<Graph>& graph);

void graph_fail(Loader* loader, const std::shared_ptr<Graph>& graph, Local<Value> error)
{
    if (graph->failed || graph->done) return;
    graph->failed = true;
    Isolate* isolate = loader->ctx->iso->isolate;
    Local<Context> context = loader->ctx->context.Get(isolate);
    (void)graph->resolver.Get(isolate)->Reject(context, error);
}

void record_fail(ModuleRecord* record, Local<Value> error)
{
    Isolate* isolate = record->loader->ctx->iso->isolate;
    record->state = ModuleRecord::kFailed;
    record->error.Reset(isolate, error);
    auto waiters = std::move(record->waiters);
    record->waiters.clear();
    for (auto& graph : waiters) graph_fail(record->loader, graph, error);
}

void module_reject_callback(const FunctionCallbackInfo<Value>& info)
{
    auto* record = static_cast<ModuleRecord*>(info.Data().As<External>()->Value());
    if (record->loader->closed || record->state != ModuleRecord::kFetching) return;
    record_fail(record, info.Length() ? info[0] : v8::Undefined(info.GetIsolate()).As<Value>());
}

void module_resolve_placeholder(const FunctionCallbackInfo<Value>&)
{
    // JSC's resolve accepts a JSScript. Vox only passes this function back to
    // vox_module_loader_supply*, which identifies the record by its Box.
}

void start_fetch(Loader* loader, ModuleRecord* record)
{
    Iso* iso = loader->ctx->iso;
    Isolate* isolate = iso->isolate;
    Local<Context> context = loader->ctx->context.Get(isolate);
    Local<External> data = External::New(isolate, record);
    Local<Function> resolve = Function::New(context, module_resolve_placeholder, data, 1,
        v8::ConstructorBehavior::kThrow).ToLocalChecked();
    Local<Function> reject = Function::New(context, module_reject_callback, data, 1,
        v8::ConstructorBehavior::kThrow).ToLocalChecked();
    Box* resolve_box = wrap(iso, resolve);
    resolve_box->tag = kTagModuleResolve;
    resolve_box->priv = record;
    Local<Value> arguments[] = { utf8_string(isolate, record->url.c_str(), record->url.size()), resolve, reject };
    TryCatch try_catch(isolate);
    Local<Value> ignored;
    if (!loader->fetch.Get(isolate)->Call(context, v8::Undefined(isolate), 3, arguments).ToLocal(&ignored)
        && try_catch.HasCaught() && record->state == ModuleRecord::kFetching) {
        record_fail(record, try_catch.Exception());
    }
}

void graph_load(Loader* loader, const std::shared_ptr<Graph>& graph, const std::string& url)
{
    if (graph->failed || graph->done || !graph->seen.insert(url).second) return;
    auto found = loader->records.find(url);
    if (found == loader->records.end()) {
        auto* record = new ModuleRecord();
        record->loader = loader;
        record->url = url;
        loader->records.emplace(url, record);
        record->waiters.push_back(graph);
        ++graph->pending;
        start_fetch(loader, record);
        return;
    }
    ModuleRecord* record = found->second;
    switch (record->state) {
    case ModuleRecord::kFetching:
        record->waiters.push_back(graph);
        ++graph->pending;
        break;
    case ModuleRecord::kFailed:
        graph_fail(loader, graph, record->error.Get(loader->ctx->iso->isolate));
        break;
    case ModuleRecord::kCompiled: {
        auto dependencies = record->dependencies;
        for (const auto& dependency : dependencies) graph_load(loader, graph, dependency);
        break;
    }
    }
}

MaybeLocal<v8::Module> resolve_module(Local<Context> context, size_t index, Local<v8::Module> referrer)
{
    JSContextRef ctx = context_of(context);
    Isolate* isolate = Isolate::GetCurrent();
    Loader* loader = ctx ? ctx->loader : nullptr;
    if (loader) {
        auto found = loader->by_script.find(referrer->ScriptId());
        if (found != loader->by_script.end() && index < found->second->dependencies.size()) {
            auto dependency = loader->records.find(found->second->dependencies[index]);
            if (dependency != loader->records.end() && dependency->second->state == ModuleRecord::kCompiled)
                return dependency->second->module.Get(isolate);
        }
    }
    throw_type_error(isolate, "Unable to resolve module dependency");
    return MaybeLocal<v8::Module>();
}

void settle_fulfilled(const FunctionCallbackInfo<Value>& info)
{
    Local<v8::Array> data = info.Data().As<v8::Array>();
    Local<Context> context = info.GetIsolate()->GetCurrentContext();
    Local<Value> resolver = data->Get(context, 0).ToLocalChecked();
    (void)resolver.As<v8::Promise::Resolver>()->Resolve(context, data->Get(context, 1).ToLocalChecked());
}

void settle_rejected(const FunctionCallbackInfo<Value>& info)
{
    Local<Context> context = info.GetIsolate()->GetCurrentContext();
    (void)info.Data().As<v8::Promise::Resolver>()->Reject(context,
        info.Length() ? info[0] : v8::Undefined(info.GetIsolate()).As<Value>());
}

void notify_evaluation(Loader* loader, const std::string& url, bool starting)
{
    if (loader->evaluated && !loader->closed)
        loader->evaluated(loader->owner, url.data(), static_cast<unsigned int>(url.size()), starting);
}

void graph_check(Loader* loader, const std::shared_ptr<Graph>& graph)
{
    if (graph->failed || graph->done || graph->pending > 0) return;
    graph->done = true;
    Isolate* isolate = loader->ctx->iso->isolate;
    Local<Context> context = loader->ctx->context.Get(isolate);
    Local<v8::Promise::Resolver> resolver = graph->resolver.Get(isolate);
    ModuleRecord* root = loader->records[graph->root];
    Local<v8::Module> module = root->module.Get(isolate);
    TryCatch try_catch(isolate);
    if (module->GetStatus() == v8::Module::kUninstantiated
        && !module->InstantiateModule(context, resolve_module).FromMaybe(false)) {
        (void)resolver->Reject(context, try_catch.HasCaught() ? try_catch.Exception() : v8::Undefined(isolate).As<Value>());
        return;
    }
    if (module->GetStatus() == v8::Module::kErrored) {
        (void)resolver->Reject(context, module->GetException());
        return;
    }
    bool evaluating = module->GetStatus() == v8::Module::kInstantiated;
    if (evaluating) notify_evaluation(loader, root->url, true);
    Local<Value> result;
    bool evaluated = module->Evaluate(context).ToLocal(&result);
    if (evaluating) notify_evaluation(loader, root->url, false);
    if (!evaluated) {
        (void)resolver->Reject(context, try_catch.HasCaught() ? try_catch.Exception() : v8::Undefined(isolate).As<Value>());
        return;
    }
    Local<Value> value = graph->dynamic ? module->GetModuleNamespace() : v8::Undefined(isolate).As<Value>();
    if (!result->IsPromise()) {
        (void)resolver->Resolve(context, value);
        return;
    }
    Local<v8::Promise> promise = result.As<v8::Promise>();
    if (promise->State() == v8::Promise::kFulfilled) {
        (void)resolver->Resolve(context, value);
        return;
    }
    if (promise->State() == v8::Promise::kRejected) {
        (void)resolver->Reject(context, promise->Result());
        return;
    }
    Local<v8::Array> data = v8::Array::New(isolate, 2);
    (void)data->Set(context, 0, resolver);
    (void)data->Set(context, 1, value);
    Local<Function> fulfilled = Function::New(context, settle_fulfilled, data).ToLocalChecked();
    Local<Function> rejected = Function::New(context, settle_rejected, resolver).ToLocalChecked();
    (void)promise->Then(context, fulfilled, rejected);
}

std::shared_ptr<Graph> start_graph(Loader* loader, const std::string& url, Local<v8::Promise::Resolver> resolver,
    bool dynamic)
{
    auto graph = std::make_shared<Graph>();
    graph->root = url;
    graph->dynamic = dynamic;
    graph->resolver.Reset(loader->ctx->iso->isolate, resolver);
    graph_load(loader, graph, url);
    graph_check(loader, graph);
    return graph;
}

JSValueRef supply_source(JSGlobalContextRef ctx, JSObjectRef resolve, Local<String> source, JSValueRef* exception)
{
    Iso* iso = ctx->iso;
    Isolate* isolate = iso->isolate;
    Box* box = box_of(resolve);
    if (!box || box->tag != kTagModuleResolve) return nullptr;
    auto* record = static_cast<ModuleRecord*>(box->priv);
    Loader* loader = record->loader;
    if (loader->closed || record->state != ModuleRecord::kFetching) return ref(&g_undefined);
    ++g_counters.modules;
    TryCatch try_catch(isolate);
    v8::ScriptOrigin origin(utf8_string(isolate, record->url.c_str(), record->url.size()), 0, 0, false, -1,
        Local<Value>(), false, false, true);
    v8::ScriptCompiler::Source compile_source(source, origin);
    Local<v8::Module> module;
    if (!v8::ScriptCompiler::CompileModule(isolate, &compile_source).ToLocal(&module)) {
        // As with JSC, a parse failure rejects the importing graph rather than
        // the supply call itself.
        record_fail(record, try_catch.HasCaught() ? try_catch.Exception() : v8::Undefined(isolate).As<Value>());
        return ref(&g_undefined);
    }
    (void)exception;
    record->module.Reset(isolate, module);
    loader->by_script[module->ScriptId()] = record;
    Local<v8::FixedArray> requests = module->GetModuleRequests();
    for (int i = 0; i < requests->Length(); ++i) {
        Local<v8::ModuleRequest> request = requests->Get(i).As<v8::ModuleRequest>();
        std::string specifier = utf8_of(isolate, request->GetSpecifier());
        record->dependencies.push_back(is_absolute_url(specifier) ? specifier : resolve_url(specifier, record->url));
    }
    record->state = ModuleRecord::kCompiled;
    auto waiters = std::move(record->waiters);
    record->waiters.clear();
    // Request every dependency before this record stops counting as pending:
    // a synchronous supply of the first dependency must not link the graph
    // before its siblings have been requested.
    for (auto& graph : waiters) {
        auto dependencies = record->dependencies;
        for (const auto& dependency : dependencies) graph_load(loader, graph, dependency);
        --graph->pending;
    }
    for (auto& graph : waiters) graph_check(loader, graph);
    return ref(&g_undefined);
}

}  // namespace

void close_loader(JSGlobalContextRef ctx)
{
    Loader* loader = ctx->loader;
    if (!loader) return;
    ctx->loader = nullptr;
    for (auto& entry : loader->records) {
        entry.second->module.Reset();
        entry.second->error.Reset();
        entry.second->waiters.clear();
        delete entry.second;
    }
    loader->fetch.Reset();
    delete loader;
}

MaybeLocal<v8::Promise> vox_v8_dynamic_import(Local<Context> context, Local<v8::Data>, Local<Value> resource_name,
    Local<String> specifier, Local<v8::FixedArray>)
{
    Isolate* isolate = Isolate::GetCurrent();
    Local<v8::Promise::Resolver> resolver;
    if (!v8::Promise::Resolver::New(context).ToLocal(&resolver)) return MaybeLocal<v8::Promise>();
    JSContextRef ctx = context_of(context);
    Loader* loader = ctx ? ctx->loader : nullptr;
    if (!loader || loader->closed) {
        (void)resolver->Reject(context, v8::Exception::TypeError(utf8_string(isolate, "Module loading is unavailable")));
        return resolver->GetPromise();
    }
    std::string url = utf8_of(isolate, specifier);
    if (!is_absolute_url(url)) url = resolve_url(url, resource_name->IsString() ? utf8_of(isolate, resource_name) : "");
    start_graph(loader, url, resolver, true);
    return resolver->GetPromise();
}

extern "C" __attribute__((visibility("default"))) void* vox_module_loader_install(JSGlobalContextRef ctx, JSObjectRef fetch, void* owner,
    VoxModuleEvaluationCallback evaluated)
{
    if (!ctx || ctx->loader) return nullptr;
    IsolateEntry entry(ctx->iso);
    Local<Object> function;
    if (!unwrap_object(ctx->iso->isolate, fetch, &function) || !function->IsFunction()) return nullptr;
    auto* loader = new Loader();
    loader->ctx = ctx;
    loader->fetch.Reset(ctx->iso->isolate, function.As<Function>());
    loader->owner = owner;
    loader->evaluated = evaluated;
    ctx->loader = loader;
    return loader;
}

extern "C" __attribute__((visibility("default"))) void vox_module_loader_close(JSGlobalContextRef ctx, void* owner)
{
    if (!ctx || !owner || ctx->loader != owner) return;
    ctx->loader->closed = true;
    ctx->loader->evaluated = nullptr;
}

extern "C" __attribute__((visibility("default"))) JSValueRef vox_module_loader_evaluate(JSGlobalContextRef ctx, const char* url, size_t length,
    JSValueRef* exception)
{
    if (!ctx || !ctx->loader || ctx->loader->closed) return nullptr;
    Entry e(ctx);
    TryCatch try_catch(e.isolate);
    Local<v8::Promise::Resolver> resolver;
    if (!v8::Promise::Resolver::New(e.context).ToLocal(&resolver)) {
        store_exception(e.iso, try_catch, exception);
        return nullptr;
    }
    start_graph(ctx->loader, std::string(url, length), resolver, false);
    Box* promise = wrap(e.iso, resolver->GetPromise());
    JSValueProtect(ctx, ref(promise));
    return ref(promise);
}

extern "C" __attribute__((visibility("default"))) JSValueRef vox_module_loader_supply(JSGlobalContextRef ctx, JSObjectRef resolve, const char* source,
    size_t sourceLength, const char*, size_t, JSValueRef* exception)
{
    if (!ctx) return nullptr;
    Entry e(ctx);
    return supply_source(ctx, resolve, utf8_string(e.isolate, source, sourceLength), exception);
}

extern "C" __attribute__((visibility("default"))) JSValueRef vox_module_loader_supply_value(JSGlobalContextRef ctx, JSObjectRef resolve, JSValueRef source,
    const char*, size_t, bool diagnostics, JSValueRef* exception)
{
    if (!ctx || !JSValueIsString(ctx, source)) return nullptr;
    Entry e(ctx);
    Local<String> text = unwrap(e.isolate, source).As<String>();
    JSValueRef result = supply_source(ctx, resolve, text, exception);
    if (result && diagnostics)
        fprintf(stderr, "Vox module source: supplied rooted UTF-16 string units=%d\n", text->Length());
    return result;
}
