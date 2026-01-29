//! DesktopUI NIF Build Configuration
//!
//! This build.zig provides a native Zig build system for compiling the DesktopUI NIF.
//! It's an alternative to the Mix compiler, useful for:
//! - Building the NIF in isolation without Elixir
//! - Debugging Zig-specific compilation issues
//! - CI/CD environments that prefer Zig over Mix
//!
//! Usage:
//!   # Native build
//!   ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
//!   zig build
//!
//!   # Cross-compile for ARM64 Linux
//!   ERTS_INCLUDE_DIR=$(erl -noshell -eval "io:format('~s/erts-~s/include', [code:root_dir(), erlang:system_info(version)]).") \
//!   zig build -Dtarget=aarch64-linux-gnu

const std = @import("std");

/// Build entry point - called by zig build
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get ERTS include directory from option or environment
    const erts_include = getErtsIncludePath(b) orelse {
        std.debug.print(
            \\Error: ERTS_INCLUDE_DIR not set
            \\
            \\Please set the ERTS_INCLUDE_DIR environment variable to point to your
            \\Erlang/OTP installation include directory.
            \\
            \\Example:
            \\  ERTS_INCLUDE_DIR=/usr/lib/erlang/erts-14.2.1/include zig build
            \\
            \\Or use the -Derts-include option:
            \\  zig build -Derts-include=/usr/lib/erlang/erts-14.2.1/include
            \\
        , .{});
        std.process.exit(1);
    };

    // Create shared library for the NIF
    const nif_lib = b.addSharedLibrary(.{
        .name = "desktop_ui_nif",
        .target = target,
        .optimize = optimize,
    });

    // Add C source files
    nif_lib.addCSourceFiles(.{
        .files = &.{
            "c_src/desktop_ui_nif.c",
        },
        .flags = &.{
            "-fPIC",
            "-Wall",
            "-Wextra",
        },
    });

    // Add ERTS include path for erl_nif.h
    nif_lib.addIncludePath(.{ .path = erts_include });

    // Link SDL2 as a system library
    nif_lib.linkSystemLibrary("SDL2");
    nif_lib.linkLibC();

    // Get the appropriate output file name based on target
    const output_name = getOutputFileName(target.result);

    // Install the compiled library to priv directory
    const install_step = b.addInstallArtifact(nif_lib, .{
        .dest_dir = .{ .custom = "priv" },
        .dest_sub_path = output_name,
    });

    // Add install step to the default build step
    b.getInstallStep().dependOn(&install_step.step);

    // Optionally add a "check" step that builds without installing
    const check_step = b.step("check", "Build the NIF without installing");
    check_step.dependOn(&nif_lib.step);

    // Add verbose output step for debugging
    const verbose_step = b.step("verbose", "Build with verbose compiler output");
    const verbose_lib = b.addSharedLibrary(.{
        .name = "desktop_ui_nif",
        .target = target,
        .optimize = optimize,
    });
    verbose_lib.addCSourceFiles(.{
        .files = &.{"c_src/desktop_ui_nif.c"},
        .flags = &.{ "-fPIC", "-Wall", "-Wextra", "-v" },
    });
    verbose_lib.addIncludePath(.{ .path = erts_include });
    verbose_lib.linkSystemLibrary("SDL2");
    verbose_lib.linkLibC();
    const verbose_install = b.addInstallArtifact(verbose_lib, .{
        .dest_dir = .{ .custom = "priv" },
        .dest_sub_path = output_name,
    });
    verbose_step.dependOn(&verbose_install.step);
}

/// Get the ERTS include directory from option or environment variable
fn getErtsIncludePath(b: *std.Build) ?[]const u8 {
    // First check for command-line option
    if (b.option([]const u8, "erts-include", "Path to ERTS include directory")) |path| {
        return path;
    }

    // Fall back to environment variable
    if (std.process.getEnvVarOwned(b.allocator, "ERTS_INCLUDE_DIR")) catch {
        return null;
    }) |path| {
        return b.dupe(path);
    }

    return null;
}

/// Get the output file name based on the target platform
fn getOutputFileName(target: std.Target) []const u8 {
    return switch (target.os.tag) {
        .windows => "desktop_ui_nif.dll",
        .macos => "desktop_ui_nif.dylib",
        else => "desktop_ui_nif.so",
    };
}
