// Opt-in first-fault evidence. The handler reads through Mach rather than
// dereferencing possibly corrupt pointers, and exits without allocator cleanup.
#ifndef VOX_PRECISE_SCROLL_FAULTS_H
#define VOX_PRECISE_SCROLL_FAULTS_H
#include <dispatch/dispatch.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <mach-o/dyld.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ucontext.h>
#include <unistd.h>

static _Atomic int scroll_fault_entered;
static uint64_t scroll_fault_addresses[128];
static unsigned char scroll_fault_depths[128];
static unsigned scroll_fault_count;

static void scroll_fault_text(const char *text) {
    write(STDERR_FILENO, text, strlen(text));
}

static void scroll_fault_hex(const char *label, uint64_t value) {
    char digits[16];
    for (unsigned i = 0; i < 16; ++i)
        digits[15-i] = "0123456789abcdef"[(value >> (i*4)) & 15];
    scroll_fault_text(label);
    write(STDERR_FILENO, digits, sizeof digits);
}

static size_t scroll_fault_read(uint64_t address, void *bytes, size_t size) {
    mach_vm_size_t actual = 0;
    return mach_vm_read_overwrite(mach_task_self(), address, size,
        (mach_vm_address_t)bytes, &actual) == KERN_SUCCESS ? actual : 0;
}

static void scroll_fault_enqueue(uint64_t address, unsigned depth) {
    if (address < 0x100000000ULL || scroll_fault_count >= 128) return;
    for (unsigned i = 0; i < scroll_fault_count; ++i)
        if (scroll_fault_addresses[i] == address) return;
    scroll_fault_addresses[scroll_fault_count] = address;
    scroll_fault_depths[scroll_fault_count++] = depth;
}

static void scroll_fault_memory(void) {
    // Breadth first: every register gets a chance before traversing children.
    for (unsigned item = 0; item < scroll_fault_count; ++item) {
        uint64_t words[64] = {0};
        size_t size = scroll_fault_read(scroll_fault_addresses[item], words, sizeof words);
        if (!size) continue;
        scroll_fault_hex("SCROLL_FAULT_MEMORY address=", scroll_fault_addresses[item]);
        scroll_fault_hex(" bytes=", size);
        scroll_fault_text("\n");
        for (unsigned i = 0; i < size/8; ++i) {
            scroll_fault_hex(i % 4 ? " " : "  ", words[i]);
            if (i % 4 == 3 || i+1 == size/8) scroll_fault_text("\n");
            if (scroll_fault_depths[item] < 2)
                scroll_fault_enqueue(words[i], scroll_fault_depths[item]+1);
        }
    }
}

static void scroll_fault_handler(int sig, siginfo_t *info, void *context) {
    if (atomic_exchange_explicit(&scroll_fault_entered, 1, memory_order_relaxed)) _exit(128+sig);
    ucontext_t *uc = context;
    uint64_t pc, lr, fp, sp;
#if defined(__arm64__)
    pc = uc->uc_mcontext->__ss.__pc; lr = uc->uc_mcontext->__ss.__lr;
    fp = uc->uc_mcontext->__ss.__fp; sp = uc->uc_mcontext->__ss.__sp;
#elif defined(__x86_64__)
    pc = uc->uc_mcontext->__ss.__rip; lr = 0;
    fp = uc->uc_mcontext->__ss.__rbp; sp = uc->uc_mcontext->__ss.__rsp;
#endif
    scroll_fault_hex("SCROLL_FAULT_FIRST signal=", sig);
    scroll_fault_hex(" address=", (uintptr_t)info->si_addr);
    scroll_fault_hex(" pc=", pc); scroll_fault_hex(" lr=", lr);
    scroll_fault_hex(" fp=", fp); scroll_fault_hex(" sp=", sp); scroll_fault_text("\n");
#if defined(__arm64__)
    for (unsigned i = 0; i < 29; ++i) {
        scroll_fault_hex("SCROLL_FAULT_REGISTER index=", i);
        scroll_fault_hex(" value=", uc->uc_mcontext->__ss.__x[i]); scroll_fault_text("\n");
        scroll_fault_enqueue(uc->uc_mcontext->__ss.__x[i], 0);
    }
#else
    uint64_t regs[] = {uc->uc_mcontext->__ss.__rax, uc->uc_mcontext->__ss.__rbx,
        uc->uc_mcontext->__ss.__rcx, uc->uc_mcontext->__ss.__rdx, uc->uc_mcontext->__ss.__rdi,
        uc->uc_mcontext->__ss.__rsi, uc->uc_mcontext->__ss.__r8, uc->uc_mcontext->__ss.__r9,
        uc->uc_mcontext->__ss.__r10, uc->uc_mcontext->__ss.__r11, uc->uc_mcontext->__ss.__r12,
        uc->uc_mcontext->__ss.__r13, uc->uc_mcontext->__ss.__r14, uc->uc_mcontext->__ss.__r15};
    for (unsigned i = 0; i < sizeof regs/sizeof regs[0]; ++i) {
        scroll_fault_hex("SCROLL_FAULT_REGISTER index=", i);
        scroll_fault_hex(" value=", regs[i]); scroll_fault_text("\n");
        scroll_fault_enqueue(regs[i], 0);
    }
#endif
    scroll_fault_enqueue(sp, 0);
    for (unsigned frame = 0; frame < 24 && fp >= 256; ++frame) {
        uint64_t words[34];
        if (scroll_fault_read(fp-256, words, sizeof words) != sizeof words) break;
        scroll_fault_hex("SCROLL_FAULT_FRAME fp=", fp);
        scroll_fault_hex(" lr=", words[33]); scroll_fault_text("\n");
        scroll_fault_enqueue(fp-256, 0);
        for (unsigned i = 0; i < 32; ++i) scroll_fault_enqueue(words[i], 0);
        if (words[32] <= fp) break;
        fp = words[32];
    }
    scroll_fault_memory();
    _exit(128+sig);
}

static void scroll_fault_install(void *unused) {
    (void)unused;
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const struct mach_header *header = _dyld_get_image_header(i);
        if (!header || header->filetype != MH_EXECUTE) continue;
        scroll_fault_hex("SCROLL_FAULT_IMAGE header=", (uintptr_t)header);
        scroll_fault_hex(" slide=", _dyld_get_image_vmaddr_slide(i));
        const struct load_command *command = (const void *)((const struct mach_header_64 *)header+1);
        for (uint32_t item = 0; item < header->ncmds; ++item) {
            if (command->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *segment = (const void *)command;
                if (!strcmp(segment->segname, "__TEXT")) {
                    uint64_t start = segment->vmaddr+_dyld_get_image_vmaddr_slide(i);
                    scroll_fault_hex(" text_start=", start);
                    scroll_fault_hex(" text_end=", start+segment->vmsize);
                }
            }
            command = (const void *)((const char *)command+command->cmdsize);
        }
        scroll_fault_text(" path_hex=");
        const unsigned char *name = (const unsigned char *)_dyld_get_image_name(i);
        for (; *name; ++name) {
            char pair[] = {"0123456789abcdef"[*name >> 4], "0123456789abcdef"[*name & 15]};
            write(STDERR_FILENO, pair, sizeof pair);
        }
        scroll_fault_text("\n");
    }
    struct sigaction action = {0};
    action.sa_sigaction = scroll_fault_handler;
    action.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &action, NULL);
    sigaction(SIGBUS, &action, NULL);
    scroll_fault_text("SCROLL_FAULT_RECORDER installed\n");
}

static void scroll_fault_schedule(void) {
    const char *enabled = getenv("VOX_PRECISE_CAPTURE_FAULTS");
    if (enabled && !strcmp(enabled, "1"))
        dispatch_async_f(dispatch_get_main_queue(), NULL, scroll_fault_install);
}
#endif
