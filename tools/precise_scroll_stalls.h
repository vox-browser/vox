#ifndef VOX_PRECISE_SCROLL_STALLS_H
#define VOX_PRECISE_SCROLL_STALLS_H

// Diagnostic only: bounded snapshots of this process's main-thread stack
// during a slow native display callback or delayed input delivery between
// callbacks. Resolve symbols after input ends;
// dyld/malloc locks must never be acquired while the main thread is suspended.
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <mach/thread_status.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#import <QuartzCore/QuartzCore.h>

enum { stall_sample_limit = 1024, stall_stack_limit = 96, stall_frame_limit = 512 };
typedef struct { uint64_t id, previous_id, previous_start, start; unsigned inputs; } StallScope;
typedef struct { uint64_t id, time, start; unsigned count, inputs; uintptr_t pc[stall_stack_limit]; } StallSample;
typedef struct { uint64_t id, start, end; unsigned inputs; } StallFrame;
static StallSample stall_samples[stall_sample_limit];
static StallFrame stall_frames[stall_frame_limit];
static unsigned stall_sample_count, stall_frame_count, stall_failures;
static _Atomic unsigned stall_dropped;
static uint64_t stall_sequence, stall_threshold_ns;
static _Atomic uint64_t stall_current_id, stall_current_start;
static _Atomic uint64_t stall_next_input_due;
static _Atomic unsigned stall_last_input_sequence;
static dispatch_source_t stall_timer;
static dispatch_queue_t stall_queue;
static thread_t stall_main_thread;
static uintptr_t stall_stack_low, stall_stack_high;

static uint64_t stall_now(void) { return (uint64_t)(CACurrentMediaTime() * 1e9); }
static uintptr_t stall_code_address(uintptr_t address) {
#if defined(__aarch64__) || defined(__arm64__)
    // Strip return-address authentication from system framework frames. The
    // current macOS userspace mappings fit the low 48-bit virtual range.
    return address & UINT64_C(0x0000ffffffffffff);
#else
    return address;
#endif
}
static void stall_capture(void) {
    uint64_t id = atomic_load_explicit(&stall_current_id, memory_order_acquire);
    uint64_t start = atomic_load_explicit(&stall_current_start, memory_order_relaxed);
    unsigned inputs = 0;
    if (!id) {
        inputs = atomic_load_explicit(&stall_last_input_sequence, memory_order_acquire);
        if (!inputs) return;
        start = atomic_load_explicit(&stall_next_input_due, memory_order_relaxed);
    }
    uint64_t now = stall_now();
    if (now < start || now - start < stall_threshold_ns) return;
    if (stall_sample_count == stall_sample_limit) { ++stall_dropped; return; }
    StallSample sample = {.id=id, .time=now, .start=start, .inputs=inputs};
    if (thread_suspend(stall_main_thread) != KERN_SUCCESS) { ++stall_failures; return; }
    uintptr_t fp=0, sp=0, pc=0;
#if defined(__aarch64__) || defined(__arm64__)
    arm_thread_state64_t state;
    mach_msg_type_number_t count=ARM_THREAD_STATE64_COUNT;
    kern_return_t result=thread_get_state(stall_main_thread, ARM_THREAD_STATE64,
        (thread_state_t)&state, &count);
    if (result==KERN_SUCCESS) {
        fp=arm_thread_state64_get_fp(state); sp=arm_thread_state64_get_sp(state);
        pc=arm_thread_state64_get_pc(state);
    }
#elif defined(__x86_64__)
    x86_thread_state64_t state;
    mach_msg_type_number_t count=x86_THREAD_STATE64_COUNT;
    kern_return_t result=thread_get_state(stall_main_thread, x86_THREAD_STATE64,
        (thread_state_t)&state, &count);
    if (result==KERN_SUCCESS) { fp=state.__rbp; sp=state.__rsp; pc=state.__rip; }
#else
    kern_return_t result=KERN_NOT_SUPPORTED;
#endif
    if (result==KERN_SUCCESS) {
        sample.pc[sample.count++]=stall_code_address(pc);
        while (sample.count < stall_stack_limit && fp >= sp && fp >= stall_stack_low
            && fp <= stall_stack_high - 2*sizeof(uintptr_t) && !(fp % sizeof(uintptr_t))) {
            uintptr_t words[2]; mach_vm_size_t read=0;
            if (mach_vm_read_overwrite(mach_task_self(), fp, sizeof(words),
                    (mach_vm_address_t)words, &read)!=KERN_SUCCESS || read!=sizeof(words)) break;
            sample.pc[sample.count++]=stall_code_address(words[1]);
            if (words[0] <= fp) break;
            fp=words[0];
        }
    }
    kern_return_t resumed=thread_resume(stall_main_thread);
    if (result!=KERN_SUCCESS || resumed!=KERN_SUCCESS) { ++stall_failures; return; }
    // A callback or input can finish between the first read and suspension.
    // Keep only snapshots whose observation context still matches.
    bool same_frame = id && id==atomic_load_explicit(&stall_current_id, memory_order_acquire);
    bool same_gap = !id && !atomic_load_explicit(&stall_current_id, memory_order_acquire)
        && inputs==atomic_load_explicit(&stall_last_input_sequence, memory_order_acquire);
    if (same_frame || same_gap)
        stall_samples[stall_sample_count++]=sample;
}
static void stall_input_progress(unsigned inputs, uint64_t interval_ns) {
    if (!stall_threshold_ns) return;
    atomic_store_explicit(&stall_last_input_sequence,0,memory_order_release);
    atomic_store_explicit(&stall_next_input_due,stall_now()+interval_ns,memory_order_relaxed);
    atomic_store_explicit(&stall_last_input_sequence,inputs,memory_order_release);
}
static void stall_inputs_end(void) {
    atomic_store_explicit(&stall_last_input_sequence,0,memory_order_release);
}
static void stall_monitor_start(double milliseconds) {
    if (!(milliseconds > 0)) return;
    stall_threshold_ns=(uint64_t)(milliseconds*1e6);
    stall_main_thread=mach_thread_self();
    stall_stack_high=(uintptr_t)pthread_get_stackaddr_np(pthread_self());
    stall_stack_low=stall_stack_high-pthread_get_stacksize_np(pthread_self());
    stall_queue=dispatch_queue_create("org.vox.precise-scroll-stalls", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(stall_queue, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
    stall_timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,stall_queue);
    dispatch_source_set_timer(stall_timer,dispatch_time(DISPATCH_TIME_NOW,0),5*NSEC_PER_MSEC,NSEC_PER_MSEC);
    dispatch_source_set_event_handler(stall_timer, ^{ stall_capture(); });
    dispatch_resume(stall_timer);
}
static StallScope stall_frame_begin(unsigned inputs) {
    if (!stall_threshold_ns) return (StallScope){0};
    StallScope scope={.id=++stall_sequence, .start=stall_now(), .inputs=inputs,
        .previous_id=atomic_load(&stall_current_id), .previous_start=atomic_load(&stall_current_start)};
    atomic_store(&stall_current_id,0);
    atomic_store_explicit(&stall_current_start,scope.start,memory_order_relaxed);
    atomic_store_explicit(&stall_current_id,scope.id,memory_order_release);
    return scope;
}
static void stall_frame_end(StallScope scope) {
    if (!scope.id) return;
    uint64_t end=stall_now();
    atomic_store(&stall_current_id,0);
    atomic_store_explicit(&stall_current_start,scope.previous_start,memory_order_relaxed);
    atomic_store_explicit(&stall_current_id,scope.previous_id,memory_order_release);
    if (end-scope.start < stall_threshold_ns) return;
    if (stall_frame_count < stall_frame_limit)
        stall_frames[stall_frame_count++]=(StallFrame){scope.id,scope.start,end,scope.inputs};
    else ++stall_dropped;
}
static void stall_hex(const char *value) {
    if (value) for (const unsigned char *p=(const unsigned char *)value; *p; ++p) fprintf(stderr,"%02x",*p);
}
static void stall_monitor_finish(double epoch) {
    if (!stall_timer) return;
    stall_inputs_end();
    atomic_store(&stall_current_id,0);
    dispatch_source_cancel(stall_timer);
    dispatch_sync(stall_queue, ^{});
    mach_port_deallocate(mach_task_self(),stall_main_thread);
    fprintf(stderr,"SCROLL_STALL_DIAGNOSTIC threshold_ms=%g samples=%u frames=%u dropped=%u failures=%u\n",
        stall_threshold_ns/1e6,stall_sample_count,stall_frame_count,stall_dropped,stall_failures);
    for (unsigned i=0;i<stall_frame_count;++i) {
        StallFrame f=stall_frames[i];
        fprintf(stderr,"SCROLL_STALL_FRAME id=%llu start_us=%.3f end_us=%.3f inputs=%u\n",
            f.id,(f.start/1e9-epoch)*1e6,(f.end/1e9-epoch)*1e6,f.inputs);
    }
    uintptr_t *symbols=calloc((size_t)stall_sample_count*stall_stack_limit+1, sizeof(uintptr_t));
    unsigned symbol_count=0;
    if (!symbols) { fputs("SCROLL_ERROR stall symbol allocation failed\n",stderr); return; }
    for (unsigned i=0;i<stall_sample_count;++i) {
        StallSample *s=&stall_samples[i];
        if (s->id)
            fprintf(stderr,"SCROLL_STALL_SAMPLE %u frame=%llu t_us=%.3f age_us=%.3f pcs=",i,s->id,
                (s->time/1e9-epoch)*1e6,(s->time-s->start)/1e3);
        else
            fprintf(stderr,"SCROLL_STALL_GAP_SAMPLE %u inputs=%u t_us=%.3f late_us=%.3f pcs=",i,s->inputs,
                (s->time/1e9-epoch)*1e6,(s->time-s->start)/1e3);
        for (unsigned j=0;j<s->count;++j) fprintf(stderr,"%s%llx",j?",":"",(unsigned long long)s->pc[j]);
        fputc('\n',stderr);
        for (unsigned j=0;j<s->count;++j) {
            uintptr_t pc=s->pc[j]; bool seen=false;
            for (unsigned k=0;k<symbol_count;++k) if (symbols[k]==pc) { seen=true; break; }
            if (seen) continue;
            symbols[symbol_count++]=pc;
            Dl_info info={0};dladdr((void *)pc,&info);
            fprintf(stderr,"SCROLL_STALL_SYMBOL pc=%llx base=%llx path_hex=",(unsigned long long)pc,
                (unsigned long long)(uintptr_t)info.dli_fbase);stall_hex(info.dli_fname);
            fputs(" name_hex=",stderr);stall_hex(info.dli_sname);fputc('\n',stderr);
        }
    }
    free(symbols);
}
#endif
