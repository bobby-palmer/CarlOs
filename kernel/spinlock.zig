const std = @import("std");
const atomic = std.atomic;

pub const SpinLock = struct {
    locked: atomic.Value(bool) = atomic.Value(bool).init(false),

    /// Block until lock can be aquired
    pub fn lock(self: *SpinLock) void {
        while (self.locked.swap(true, .acquire)) {
            atomic.spinLoopHint();
        }
    }

    /// Release lock
    pub fn unlock(self: *SpinLock) void {
        self.locked.store(false, .release);
    }

    /// return true if locked successfully
    pub fn tryLock(self: *SpinLock) bool {
        return !self.locked.swap(true, .acquire);
    }
};
