//! Process control block for storing state

const Process = @This();

const std = @import("std");
const Spinlock = @import("Spinlock.zig");

lock: Spinlock,
