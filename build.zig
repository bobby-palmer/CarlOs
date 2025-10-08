const std = @import("std");

pub fn build(b: *std.Build) void {
    const run_kernel = b.addSystemCommand(&[_][]const u8 {
        "qemu-system-riscv64",
        "-machine", "virt",
        "-bios", "default",
        "-nographic",
        "-serial",
        "mon:stdio",
        "--no-reboot",
    });

    const run_step = b.step("run", "Run the kernel in qemu");
    run_step.dependOn(&run_kernel.step);
}
