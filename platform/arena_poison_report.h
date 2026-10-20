// Names the arena behind a fault on a poisoned (write-protected) block, so a
// stale reference found by VOX_ARENA_POISON identifies its owner.
#ifndef VOX_ARENA_POISON_REPORT_H
#define VOX_ARENA_POISON_REPORT_H
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include <stdatomic.h>

typedef struct {
	char *start;
	char *end;
	char label[96];
} VoxPoisonedRange;

#define VOX_POISONED_RANGE_LIMIT 65536
static VoxPoisonedRange vox_poisoned_ranges[VOX_POISONED_RANGE_LIMIT];
static _Atomic int vox_poisoned_range_count;
static _Atomic int vox_poisoned_range_ready[VOX_POISONED_RANGE_LIMIT];

static void vox_note_poisoned_range(void *start, void *end, const char *label) {
	int index = atomic_fetch_add_explicit(&vox_poisoned_range_count, 1, memory_order_relaxed);
	if (index >= VOX_POISONED_RANGE_LIMIT) return;
	vox_poisoned_ranges[index].start = (char *)start;
	vox_poisoned_ranges[index].end = (char *)end;
	strncpy(vox_poisoned_ranges[index].label, label ? label : "unnamed arena", 95);
	vox_poisoned_ranges[index].label[95] = 0;
	atomic_store_explicit(&vox_poisoned_range_ready[index], 1, memory_order_release);
}

static void vox_poison_fault_handler(int sig, siginfo_t *info, void *context) {
	(void)context;
	char *address = (char *)info->si_addr;
	int count = atomic_load_explicit(&vox_poisoned_range_count, memory_order_relaxed);
	if (count > VOX_POISONED_RANGE_LIMIT) count = VOX_POISONED_RANGE_LIMIT;
	for (int index = count - 1; index >= 0; index--) {
		if (!atomic_load_explicit(&vox_poisoned_range_ready[index], memory_order_acquire)) continue;
		VoxPoisonedRange range = vox_poisoned_ranges[index];
		if (address >= range.start && address < range.end) {
			const char *prefix = "Vox poisoned arena access: ";
			write(2, prefix, strlen(prefix));
			write(2, range.label, strlen(range.label));
			write(2, "\n", 1);
			break;
		}
	}
	signal(sig, SIG_DFL);
	raise(sig);
}

static void vox_install_poison_fault_handler(void) {
	struct sigaction action;
	memset(&action, 0, sizeof action);
	action.sa_sigaction = vox_poison_fault_handler;
	action.sa_flags = SA_SIGINFO;
	sigaction(SIGBUS, &action, NULL);
}
#endif
