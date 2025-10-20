const std = @import("std");
const Sbi = @import("sbi.zig");

pub const Stdout = struct {
    // TODO implmeemnt initializing the UART

    pub fn writer(buffer: []u8) std.io.Writer {
        return std.io.Writer {
            .buffer = buffer,
            .vtable = &std.io.Writer.VTable{
                .drain = drain
            }
        };
    }

    fn drain(_: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
        std.debug.assert(data.len > 0);

        var total_written: usize = 0;

        for (0..data.len - 1) |line_idx| {
            const this_write: usize = @intCast(Sbi.DebugConsole.consoleWrite(data[line_idx]) catch {
                return std.io.Writer.Error.WriteFailed;
            });

            total_written += this_write;

            if (this_write < data[line_idx].len) {
                return total_written;
            }
        }

        for (0..splat) |_| {
            const this_write: usize = @intCast(Sbi.DebugConsole.consoleWrite(data[data.len - 1]) catch {
                return std.io.Writer.Error.WriteFailed;
            });

            total_written += this_write;

            if (this_write < data[data.len - 1].len) {
                return total_written;
            }
        }

        return total_written;
    }
};
