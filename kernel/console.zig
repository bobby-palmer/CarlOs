//! Screen printing module!

const std = @import("std");
const sbi = @import("sbi.zig");

const Writer = std.io.Writer;

pub const Sbi = struct {
    
    /// Constuct a writer that prints to OpenSBI debug console
    pub fn writer(buffer: []u8) Writer {
        return Writer {
            .buffer = buffer,
            .vtable = &Writer.VTable{
                .drain = drain,
            }
        };
    }

    fn drain(_: *std.io.Writer, data: []const []const u8, _: usize) 
        Writer.Error!usize {
        if (data.len > 0) {
            return sbi.DebugConsole.consoleWrite(data[0]) 
                catch return Writer.Error.WriteFailed;
        } else {
            return 0;
        }
    }
};

/// Temporary debug writer for early stage writing info to screen. Will
/// probably get removed later.
pub var debug_writer = Sbi.writer(&.{});
