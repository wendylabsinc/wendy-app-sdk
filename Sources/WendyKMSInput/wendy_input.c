#include "include/wendy_input.h"
#include <stdio.h>
#include <string.h>

#if defined(__linux__)

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/input.h>

static int has_abs_bit(int fd, int code) {
    unsigned char bits[(ABS_MAX + 7) / 8 + 1];
    memset(bits, 0, sizeof(bits));
    if (ioctl(fd, EVIOCGBIT(EV_ABS, sizeof(bits)), bits) < 0) return 0;
    return (bits[code / 8] >> (code % 8)) & 1;
}

int wendy_input_open(WendyInputDevice *out, char *err, int errlen) {
    memset(out, 0, sizeof(*out));
    out->fd = -1;
    int used = 0;
    for (int i = 0; i < 32; i++) {
        char path[32];
        snprintf(path, sizeof(path), "/dev/input/event%d", i);
        int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0) {
            if (errno != ENOENT && err && used < errlen)
                used += snprintf(err + used, errlen - used,
                                 "%s: open: %s; ", path, strerror(errno));
            continue;
        }
        char name[80] = "?";
        ioctl(fd, EVIOCGNAME(sizeof(name)), name);
        if (!has_abs_bit(fd, ABS_MT_POSITION_X)) {
            if (err && used < errlen)
                used += snprintf(err + used, errlen - used,
                                 "%s (%s): no ABS_MT_POSITION_X; ", path, name);
            close(fd);
            continue;
        }
        struct input_absinfo ax, ay;
        if (ioctl(fd, EVIOCGABS(ABS_MT_POSITION_X), &ax) < 0 ||
            ioctl(fd, EVIOCGABS(ABS_MT_POSITION_Y), &ay) < 0) {
            if (err && used < errlen)
                used += snprintf(err + used, errlen - used,
                                 "%s (%s): EVIOCGABS: %s; ", path, name, strerror(errno));
            close(fd);
            continue;
        }
        out->fd = fd;
        out->min_x = ax.minimum; out->max_x = ax.maximum;
        out->min_y = ay.minimum; out->max_y = ay.maximum;
        snprintf(out->name, sizeof(out->name), "%s", name);
        snprintf(out->path, sizeof(out->path), "%s", path);
        // Announce the chosen device on stderr — the single most useful line
        // when touch coordinates come out rotated/inverted on new hardware.
        fprintf(stderr, "WendyKMSInput: using %s (%s) x:[%d,%d] y:[%d,%d]\n",
                path, name, ax.minimum, ax.maximum, ay.minimum, ay.maximum);
        return 0;
    }
    if (err && errlen > 0 && used == 0)
        snprintf(err, errlen,
                 "no /dev/input/event* device with ABS_MT_POSITION_X "
                 "(is the `input` entitlement set?)");
    return -1;
}

static float normf(int32_t v, int32_t lo, int32_t hi) {
    if (hi <= lo) return 0.0f;
    float t = (float)(v - lo) / (float)(hi - lo);
    return t < 0.0f ? 0.0f : (t > 1.0f ? 1.0f : t);
}

int wendy_input_poll(WendyInputDevice *d, WendyTouchEvent *out, int cap) {
    if (d->fd < 0) return -1;
    int emitted = 0;
    struct input_event evs[64];
    for (;;) {
        if (emitted == cap) return emitted;
        ssize_t n = read(d->fd, evs, sizeof(evs));
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
                return emitted;
            return -1;  // device unplugged / fatal
        }
        if (n == 0) return emitted;
        int count = (int)(n / (ssize_t)sizeof(struct input_event));
        for (int i = 0; i < count; i++) {
            struct input_event *e = &evs[i];
            if (e->type == EV_ABS) {
                switch (e->code) {
                case ABS_MT_SLOT:        d->cur_slot = e->value; break;
                case ABS_MT_TRACKING_ID:
                    if (d->cur_slot == 0) d->slot0_active = (e->value >= 0);
                    break;
                case ABS_MT_POSITION_X:  if (d->cur_slot == 0) d->cur_x = e->value; break;
                case ABS_MT_POSITION_Y:  if (d->cur_slot == 0) d->cur_y = e->value; break;
                }
            } else if (e->type == EV_SYN && e->code == SYN_REPORT && emitted < cap) {
                float x = normf(d->cur_x, d->min_x, d->max_x);
                float y = normf(d->cur_y, d->min_y, d->max_y);
                if (d->slot0_active && !d->touching)
                    out[emitted++] = (WendyTouchEvent){WENDY_TOUCH_DOWN, x, y};
                else if (!d->slot0_active && d->touching)
                    out[emitted++] = (WendyTouchEvent){WENDY_TOUCH_UP, x, y};
                else if (d->slot0_active &&
                         (d->cur_x != d->last_x || d->cur_y != d->last_y))
                    out[emitted++] = (WendyTouchEvent){WENDY_TOUCH_MOVE, x, y};
                d->touching = d->slot0_active;
                d->last_x = d->cur_x;
                d->last_y = d->cur_y;
            }
        }
    }
}

void wendy_input_close(WendyInputDevice *d) {
    if (d->fd >= 0) close(d->fd);
    d->fd = -1;
}

#else  // !__linux__ — compile-clean stubs so macOS dev builds work.

int wendy_input_open(WendyInputDevice *out, char *err, int errlen) {
    memset(out, 0, sizeof(*out));
    out->fd = -1;
    if (err && errlen > 0)
        snprintf(err, errlen, "touch input is Linux-only");
    return -1;
}

int wendy_input_poll(WendyInputDevice *d, WendyTouchEvent *out, int cap) {
    (void)d; (void)out; (void)cap;
    return -1;
}

void wendy_input_close(WendyInputDevice *d) { d->fd = -1; }

#endif

int wendy_input_fd(const WendyInputDevice *d) { return d->fd; }
