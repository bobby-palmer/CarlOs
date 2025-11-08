const std = @import("std");

pub fn build(b: *std.Build) void {

    // RISC-V 64-bit, no OS
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .riscv64,
            .os_tag = .freestanding,
        },
    });

    // const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "kernel",
        .root_module = b.createModule(.{
            .root_source_file = b.path("kernel/kmain.zig"),
            .code_model = .medium,
            .target = target,
            .optimize = .Debug,
            .strip = false,
        })
    });

    exe.addAssemblyFile(b.path("kernel/boot.S"));
    exe.setLinkerScript(b.path("kernel/kernel.ld"));

    b.installArtifact(exe);

    // QEMU

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

    // DEBUG
    const get_addr = b.addSystemCommand(&[_][]const u8 { "riscv64-unknown-elf-addr2line" });

    get_addr.addArg("-e");
    get_addr.addArtifactArg(exe);
    get_addr.step.dependOn(&exe.step);

    const address_arg = b.option(
        []const u8, // The type of input expected (a string)
        "address",   // The name of the flag (used as --address)
        "The memory address."
    ) orelse &.{};

    get_addr.addArg(address_arg);

    const get_addr_step = b.step("get-addr", "NONE");
    get_addr_step.dependOn(&get_addr.step);
}
