const std = @import("std");

pub fn build(b: *std.Build) void {

    const target = b.standardTargetOptions(.{
        // RISC-V 64-bit, no OS
        .default_target = .{
            .cpu_arch = .riscv64,
            .os_tag = .freestanding,
        },
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "kernel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("kernel/kmain.zig"),
            .code_model = .medium,
            .target = target,
            .optimize = optimize,
        })
    });

    exe.setLinkerScript(b.path("kernel/kernel.ld"));

    b.installArtifact(exe);

    const run_kernel = b.addSystemCommand(&[_][]const u8 {
        "qemu-system-riscv64",
        "-machine", "virt",
        "-bios", "default",
        "-nographic",
        "-serial",
        "mon:stdio",
        "--no-reboot",
    });

    run_kernel.addArg("-kernel");
    run_kernel.addFileArg(exe.getEmittedBin());
    run_kernel.step.dependOn(&exe.step);

    const run_step = b.step("run", "Run the kernel in qemu");
    run_step.dependOn(&run_kernel.step);
}
