const std = @import("std");

pub fn build(b: *std.Build) void {

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag   = .freestanding,
        .abi      = .none
    });

    const kernel = b.addExecutable(.{
        .name     = "kernel",
        .target   = target,
        .optimize = b.standardOptimizeOption(.{}),
    });

    kernel.entry = .{ .symbol_name = "boot" };
    kernel.setLinkerScript(b.path("kernel/kernel.ld"));

    const cflags = &.{
        "-fno-omit-frame-pointer",
        "-mcmodel=medany",
        "-ffreestanding",
        "-fno-common",
        "-nostdlib",
        "-mno-relax",
        "-fno-stack-protector",
        "-fno-pie",
    };

    const cfiles = &.{
        "kernel/kmain.c",
    };


    kernel.addCSourceFiles(.{
        .files = cfiles,
        .flags = cflags
    });

    // add mem and cpu params
    const qemu = b.step("qemu", "Run Qemu");
    const runQemu = b.addSystemCommand(&.{
        "qemu-system-riscv64",
        "-nographic", 
        "-machine", "virt", 
        "-bios",    "default",
    });

    runQemu.addArg("-kernel");
    runQemu.addArtifactArg(kernel);

    qemu.dependOn(&runQemu.step);
    runQemu.step.dependOn(&kernel.step);
}
