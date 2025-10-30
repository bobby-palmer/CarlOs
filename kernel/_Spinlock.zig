const Spinlock = @This();

const std = @import("std");
const atomic = std.atomic;

locked: atomic.Value(bool) = atomic.Value(bool).init(false),

/// Block until lock can be aquired
pub fn lock(self: *Spinlock) void {
    while (self.locked.swap(true, .acquire)) {
        atomic.spinLoopHint();
    }
}

/// Release lock
pub fn unlock(self: *Spinlock) void {
    self.locked.store(false, .release);
}

/// return true if locked successfully
pub fn tryLock(self: *Spinlock) bool {
    return !self.locked.swap(true, .acquire);
}
