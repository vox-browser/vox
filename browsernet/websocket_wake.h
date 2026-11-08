#pragma once
// A WebSocket I/O thread sleeps until its socket is readable or the owning
// thread queues an outgoing frame. A pipe carries the wake-up, so an idle
// connection performs no periodic TLS reads.
#include <stdint.h>
#include <stdlib.h>
#ifdef _WIN32
#include <winsock2.h>

typedef struct {
	WSAEVENT signal;
	WSAEVENT readable;
} vox_websocket_wake;

static void *vox_websocket_wake_create(void) {
	vox_websocket_wake *wake = malloc(sizeof *wake);
	if (!wake) return NULL;
	wake->signal = WSACreateEvent();
	wake->readable = WSACreateEvent();
	if (wake->signal == WSA_INVALID_EVENT || wake->readable == WSA_INVALID_EVENT) {
		if (wake->signal != WSA_INVALID_EVENT) WSACloseEvent(wake->signal);
		if (wake->readable != WSA_INVALID_EVENT) WSACloseEvent(wake->readable);
		free(wake);
		return NULL;
	}
	return wake;
}

static void vox_websocket_wake_signal(void *pointer) {
	vox_websocket_wake *wake = pointer;
	if (wake) WSASetEvent(wake->signal);
}

static int vox_websocket_wake_wait(void *pointer, int64_t descriptor, int timeout_ms) {
	vox_websocket_wake *wake = pointer;
	if (!wake) return -1;
	SOCKET socket = (SOCKET)(uintptr_t)descriptor;
	if (WSAEventSelect(socket, wake->readable, FD_READ | FD_CLOSE)) return -1;
	WSAEVENT events[] = {wake->signal, wake->readable};
	DWORD result = WSAWaitForMultipleEvents(2, events, FALSE,
		timeout_ms < 0 ? WSA_INFINITE : (DWORD)timeout_ms, FALSE);
	if (result == WSA_WAIT_TIMEOUT) return 0;
	if (result == WSA_WAIT_EVENT_0) { WSAResetEvent(wake->signal); return 2; }
	if (result == WSA_WAIT_EVENT_0 + 1) {
		WSANETWORKEVENTS ready;
		return WSAEnumNetworkEvents(socket, wake->readable, &ready) ? -1 : 1;
	}
	return -1;
}

static void vox_websocket_wake_close(void *pointer) {
	vox_websocket_wake *wake = pointer;
	if (!wake) return;
	WSACloseEvent(wake->signal);
	WSACloseEvent(wake->readable);
	free(wake);
}
#else
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdlib.h>
#include <unistd.h>

typedef struct {
	int read_fd;
	int write_fd;
} vox_websocket_wake;

static void *vox_websocket_wake_create(void) {
	int fds[2];
	if (pipe(fds) != 0) return NULL;
	for (int i = 0; i < 2; ++i) {
		fcntl(fds[i], F_SETFL, fcntl(fds[i], F_GETFL) | O_NONBLOCK);
		fcntl(fds[i], F_SETFD, FD_CLOEXEC);
	}
	vox_websocket_wake *wake = malloc(sizeof *wake);
	if (!wake) {
		close(fds[0]);
		close(fds[1]);
		return NULL;
	}
	wake->read_fd = fds[0];
	wake->write_fd = fds[1];
	return wake;
}

// Never blocks: a full pipe already holds a pending wake-up.
static void vox_websocket_wake_signal(void *pointer) {
	vox_websocket_wake *wake = pointer;
	if (!wake) return;
	char byte = 1;
	ssize_t ignored = write(wake->write_fd, &byte, 1);
	(void)ignored;
}

// Returns 2 when signalled, 1 when the socket is readable or closed, 0 on
// timeout and -1 on failure. A negative timeout waits indefinitely.
static int vox_websocket_wake_wait(void *pointer, int64_t socket, int timeout_ms) {
	vox_websocket_wake *wake = pointer;
	if (!wake) return -1;
	struct pollfd fds[2] = {{(int)socket, POLLIN, 0}, {wake->read_fd, POLLIN, 0}};
	int ready;
	do {
		ready = poll(fds, 2, timeout_ms);
	} while (ready < 0 && errno == EINTR);
	if (ready < 0) return -1;
	if (ready == 0) return 0;
	if (fds[1].revents & POLLIN) {
		char buffer[64];
		while (read(wake->read_fd, buffer, sizeof buffer) > 0) {}
		return 2;
	}
	return 1;
}

static void vox_websocket_wake_close(void *pointer) {
	vox_websocket_wake *wake = pointer;
	if (!wake) return;
	close(wake->read_fd);
	close(wake->write_fd);
	free(wake);
}
#endif
