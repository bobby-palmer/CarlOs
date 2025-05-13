const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none
    });

    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .target = target,
        .optimize = optimize,
    });

    kernel.addCSourceFiles(.{
        .files = &.{
            "kernel/kmain.c"
        },
        .flags = &.{
            "-std=c11",
            "-g3",
            "-Wall",
            "-Wextra",
            "-fno-stack-protector",
            "-ffreestanding",
            "-nostdlib",
        }
    });

    kernel.entry = .{ .symbol_name =  "boot" };
    kernel.setLinkerScript(b.path("kernel/kernel.ld"));

    const qemu = b.step("qemu", "Run Qemu");
    const runQemu = b.addSystemCommand(&.{
        "qemu-system-riscv32",
        "-machine",
        "virt",
        "-bios",
        "default",
        "-nographic",
        "-serial",
        "mon:stdio",
       "--no-reboot",
        "-kernel",
    });

    runQemu.addArtifactArg(kernel);

    qemu.dependOn(&runQemu.step);
    runQemu.step.dependOn(&kernel.step);

}
