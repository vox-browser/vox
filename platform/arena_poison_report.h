// Names the arena behind a fault on a poisoned (write-protected) block, so a
// stale reference found by VOX_ARENA_POISON identifies its owner.
#ifndef VOX_ARENA_POISON_REPORT_H
#define VOX_ARENA_POISON_REPORT_H
#include <signal.h>
#include <string.h>
#include <unistd.h>

typedef struct {
	char *start;
	char *end;
	const char *label;
} VoxPoisonedRange;

#define VOX_POISONED_RANGE_LIMIT 65536
static VoxPoisonedRange vox_poisoned_ranges[VOX_POISONED_RANGE_LIMIT];
static volatile int vox_poisoned_range_count;

static void vox_note_poisoned_range(void *start, void *end, const char *label) {
	int index = vox_poisoned_range_count;
	if (index >= VOX_POISONED_RANGE_LIMIT) return;
	vox_poisoned_ranges[index].start = (char *)start;
	vox_poisoned_ranges[index].end = (char *)end;
	vox_poisoned_ranges[index].label = label;
	vox_poisoned_range_count = index + 1;
}

static void vox_poison_fault_handler(int sig, siginfo_t *info, void *context) {
	(void)context;
	char *address = (char *)info->si_addr;
	for (int index = vox_poisoned_range_count - 1; index >= 0; index--) {
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
