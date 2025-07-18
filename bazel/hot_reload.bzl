# hot_reload.bzl - Bazel rules for InjectionIII hot reload support
#
# Created by Claude Code on 18/07/2025.
# Copyright © 2025 John Holdsworth. All rights reserved.
#
# This file contains Bazel rules and macros for generating hot reload
# dynamic libraries that can be injected into running applications.

load("@build_bazel_rules_apple//apple:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:apple.bzl", "apple_dynamic_framework")
load("@build_bazel_rules_apple//apple/internal:apple_support.bzl", "apple_support")

def _hot_reload_dylib_impl(ctx):
    """Implementation of hot_reload_dylib rule."""
    
    # Get the Swift toolchain
    swift_toolchain = ctx.attr._swift_toolchain[SwiftToolchainInfo]
    
    # Get Apple toolchain for SDK path
    apple_toolchain = apple_common.apple_toolchain()
    
    # Get platform information
    apple_fragment = ctx.fragments.apple
    cpu = apple_fragment.single_arch_cpu
    platform = apple_fragment.single_arch_platform
    
    # Build target triple dynamically
    target_triple = "{}-apple-{}".format(cpu, platform.name_in_plist.lower())
    
    # Get SDK path dynamically
    sdk_path = apple_toolchain.sdk_dir()
    
    # Input source file
    source_file = ctx.file.source
    
    # Output dylib
    output_dylib = ctx.outputs.dylib
    
    # Collect dependencies
    dep_files = []
    swift_module_paths = []
    framework_paths = []
    
    for dep in ctx.attr.deps:
        dep_files.extend(dep.files.to_list())
        if SwiftInfo in dep:
            swift_info = dep[SwiftInfo]
            for module in swift_info.transitive_modules.to_list():
                swift_module_paths.append(module.path)
        if apple_common.Objc in dep:
            objc_info = dep[apple_common.Objc]
            for framework in objc_info.framework_search_paths.to_list():
                framework_paths.append(framework)
    
    # Build arguments for Swift compiler
    args = ctx.actions.args()
    
    # Basic Swift compilation flags
    args.add("-frontend")
    args.add("-emit-library")
    args.add("-o", output_dylib)
    args.add("-module-name", ctx.attr.module_name)
    args.add("-target", target_triple)
    args.add("-sdk", sdk_path)
    
    # Add module search paths
    for module_path in swift_module_paths:
        args.add("-I", module_path)
    
    # Add framework search paths
    for framework_path in framework_paths:
        args.add("-F", framework_path)
    
    # Linker flags for dynamic library
    args.add("-Xlinker", "-dylib")
    args.add("-Xlinker", "-interposable")
    args.add("-Xlinker", "-undefined")
    args.add("-Xlinker", "dynamic_lookup")
    
    # Enable hot reload features
    args.add("-Xfrontend", "-enable-dynamic-replacement-chaining")
    args.add("-Xfrontend", "-enable-implicit-dynamic")
    
    # Add the source file
    args.add(source_file)
    
    # Run the Swift compiler
    ctx.actions.run(
        executable = swift_toolchain.swift_worker,
        arguments = [args],
        inputs = [source_file] + dep_files,
        outputs = [output_dylib],
        mnemonic = "SwiftHotReloadCompile",
        progress_message = "Compiling hot reload dylib for %s" % source_file.short_path,
    )
    
    return [
        DefaultInfo(files = depset([output_dylib])),
        OutputGroupInfo(
            dylib = depset([output_dylib]),
            compilation_outputs = depset([output_dylib]),
        ),
    ]

# Define the hot_reload_dylib rule
hot_reload_dylib = rule(
    implementation = _hot_reload_dylib_impl,
    attrs = {
        "source": attr.label(
            allow_single_file = [".swift"],
            mandatory = True,
            doc = "The Swift source file to compile into a hot reload dylib",
        ),
        "deps": attr.label_list(
            providers = [SwiftInfo],
            doc = "List of Swift dependencies",
        ),
        "module_name": attr.string(
            mandatory = True,
            doc = "The name of the Swift module",
        ),
        "_swift_toolchain": attr.label(
            default = Label("@bazel_tools//tools/swift:toolchain"),
            providers = [SwiftToolchainInfo],
        ),
    },
    outputs = {
        "dylib": "%{name}.dylib",
    },
    fragments = ["apple"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    doc = "Compiles a Swift source file into a hot reload dynamic library",
)

def _hot_reload_target_impl(ctx):
    """Implementation of hot_reload_target rule that creates hot reload dylibs for all sources."""
    
    # Get Apple toolchain for SDK path
    apple_toolchain = apple_common.apple_toolchain()
    
    # Get platform information
    apple_fragment = ctx.fragments.apple
    cpu = apple_fragment.single_arch_cpu
    platform = apple_fragment.single_arch_platform
    
    # Build target triple dynamically
    target_triple = "{}-apple-{}".format(cpu, platform.name_in_plist.lower())
    
    # Get SDK path dynamically
    sdk_path = apple_toolchain.sdk_dir()
    
    output_dylibs = []
    
    for src in ctx.files.srcs:
        if src.extension == "swift":
            # Generate a dylib for each Swift source file
            dylib_name = src.basename.replace(".swift", ".dylib")
            dylib_output = ctx.actions.declare_file(dylib_name)
            
            # Create the hot reload dylib
            ctx.actions.run(
                executable = ctx.executable._hot_reload_compiler,
                arguments = [
                    "--source", src.path,
                    "--output", dylib_output.path,
                    "--module-name", ctx.attr.module_name,
                    "--target", target_triple,
                    "--sdk", sdk_path,
                ] + ["--dep=%s" % dep.path for dep in ctx.files.deps],
                inputs = [src] + ctx.files.deps,
                outputs = [dylib_output],
                mnemonic = "HotReloadDylib",
            )
            
            output_dylibs.append(dylib_output)
    
    return [
        DefaultInfo(files = depset(output_dylibs)),
        OutputGroupInfo(
            hot_reload_dylibs = depset(output_dylibs),
            compilation_outputs = depset(output_dylibs),
        ),
    ]

# Define the hot_reload_target rule
hot_reload_target = rule(
    implementation = _hot_reload_target_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".swift"],
            doc = "Swift source files to create hot reload dylibs for",
        ),
        "deps": attr.label_list(
            doc = "Dependencies required for compilation",
        ),
        "module_name": attr.string(
            mandatory = True,
            doc = "The name of the Swift module",
        ),
        "_hot_reload_compiler": attr.label(
            default = Label("//bazel/tools:hot_reload_compiler"),
            executable = True,
            cfg = "host",
        ),
    },
    fragments = ["apple"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    doc = "Creates hot reload dynamic libraries for Swift source files",
)

def hot_reload_wrapper(name, srcs, deps = [], module_name = None, **kwargs):
    """Wrapper macro that creates both static and dynamic libraries for hot reload support.
    
    This macro creates:
    1. A regular swift_library target for normal compilation
    2. Individual hot_reload_dylib targets for each source file
    3. A hot_reload_target that bundles all the dylibs
    
    Args:
        name: The name of the target
        srcs: List of Swift source files
        deps: List of dependencies
        module_name: Name of the Swift module (defaults to target name)
        **kwargs: Additional arguments passed to swift_library
    """
    
    if not module_name:
        module_name = name
    
    # Create the regular swift_library
    swift_library(
        name = name,
        srcs = srcs,
        deps = deps,
        module_name = module_name,
        **kwargs
    )
    
    # Create individual hot reload dylibs for each source file
    for src in srcs:
        if src.endswith(".swift"):
            src_name = src.replace("/", "_").replace(".swift", "")
            hot_reload_dylib(
                name = name + "_hot_reload_" + src_name,
                source = src,
                deps = deps + [":" + name],
                module_name = module_name + "_HotReload_" + src_name,
            )
    
    # Create a target that bundles all hot reload dylibs
    hot_reload_target(
        name = name + "_hot_reload",
        srcs = srcs,
        deps = deps + [":" + name],
        module_name = module_name,
    )

def injection_enabled_swift_library(name, srcs, deps = [], **kwargs):
    """Creates a Swift library with injection capabilities.
    
    This is a convenience macro that sets up a Swift library with all the
    necessary configurations for hot reload injection.
    
    Args:
        name: The name of the target
        srcs: List of Swift source files
        deps: List of dependencies
        **kwargs: Additional arguments
    """
    
    # Add injection-specific compiler flags
    copts = kwargs.get("copts", [])
    copts.extend([
        "-Xfrontend", "-enable-dynamic-replacement-chaining",
        "-Xfrontend", "-enable-implicit-dynamic",
    ])
    
    # Add injection-specific linker flags
    linkopts = kwargs.get("linkopts", [])
    linkopts.extend([
        "-Xlinker", "-interposable",
    ])
    
    kwargs["copts"] = copts
    kwargs["linkopts"] = linkopts
    
    # Use the hot reload wrapper to create both static and dynamic versions
    hot_reload_wrapper(
        name = name,
        srcs = srcs,
        deps = deps,
        **kwargs
    )

def _injection_bundle_impl(ctx):
    """Implementation for injection_bundle rule."""
    
    # Collect all dylibs from dependencies
    dylib_files = []
    for dep in ctx.attr.deps:
        if OutputGroupInfo in dep:
            output_group = dep[OutputGroupInfo]
            if hasattr(output_group, "hot_reload_dylibs"):
                dylib_files.extend(output_group.hot_reload_dylibs.to_list())
    
    # Create a bundle directory
    bundle_dir = ctx.actions.declare_directory(ctx.attr.bundle_name)
    
    # Copy all dylibs to the bundle
    ctx.actions.run_shell(
        command = """
        mkdir -p {bundle_dir}
        for dylib in {dylibs}; do
            cp "$dylib" {bundle_dir}/
        done
        """.format(
            bundle_dir = bundle_dir.path,
            dylibs = " ".join([f.path for f in dylib_files])
        ),
        inputs = dylib_files,
        outputs = [bundle_dir],
        mnemonic = "CreateInjectionBundle",
    )
    
    return [
        DefaultInfo(files = depset([bundle_dir])),
        OutputGroupInfo(
            injection_bundle = depset([bundle_dir]),
        ),
    ]

# Define the injection_bundle rule
injection_bundle = rule(
    implementation = _injection_bundle_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "Targets that provide hot reload dylibs",
        ),
        "bundle_name": attr.string(
            mandatory = True,
            doc = "Name of the injection bundle",
        ),
    },
    doc = "Creates a bundle of hot reload dylibs for injection",
)

def create_injection_bundle(name, targets, **kwargs):
    """Creates an injection bundle from a list of targets.
    
    Args:
        name: Name of the bundle
        targets: List of targets that have hot reload capabilities
        **kwargs: Additional arguments
    """
    
    injection_bundle(
        name = name,
        deps = [target + "_hot_reload" for target in targets],
        bundle_name = name + ".bundle",
        **kwargs
    )

# Platform-specific configurations removed - now using dynamic platform detection

def ios_injection_library(name, srcs, deps = [], **kwargs):
    """Creates an iOS library with injection capabilities.
    
    Note: Platform detection is now automatic based on build configuration.
    Use --ios_multi_cpus or --cpu flags to target specific platforms.
    """
    
    injection_enabled_swift_library(
        name = name,
        srcs = srcs,
        deps = deps,
        **kwargs
    )

def macos_injection_library(name, srcs, deps = [], **kwargs):
    """Creates a macOS library with injection capabilities.
    
    Note: Platform detection is now automatic based on build configuration.
    Use --macos_cpus or --cpu flags to target specific architectures.
    """
    
    injection_enabled_swift_library(
        name = name,
        srcs = srcs,
        deps = deps,
        **kwargs
    )

def _injection_test_impl(ctx):
    """Implementation for injection_test rule."""
    
    # Create a test script that loads the dylib and runs tests
    test_script = ctx.actions.declare_file(ctx.label.name + "_test.sh")
    
    ctx.actions.write(
        output = test_script,
        content = """#!/bin/bash
        
        # Load the injection dylib
        export DYLD_INSERT_LIBRARIES={dylib}
        
        # Run the test
        exec {test_binary} "$@"
        """.format(
            dylib = ctx.file.dylib.path,
            test_binary = ctx.executable.test_binary.path,
        ),
        is_executable = True,
    )
    
    return [
        DefaultInfo(
            executable = test_script,
            runfiles = ctx.runfiles(files = [ctx.file.dylib, ctx.executable.test_binary]),
        ),
    ]

# Define the injection_test rule
injection_test = rule(
    implementation = _injection_test_impl,
    attrs = {
        "dylib": attr.label(
            allow_single_file = [".dylib"],
            mandatory = True,
            doc = "The injection dylib to load",
        ),
        "test_binary": attr.label(
            executable = True,
            cfg = "target",
            mandatory = True,
            doc = "The test binary to run",
        ),
    },
    test = True,
    doc = "Runs tests with injection dylib loaded",
)

def injection_test_suite(name, dylib, test_targets, **kwargs):
    """Creates a test suite that runs tests with injection enabled.
    
    Args:
        name: Name of the test suite
        dylib: The injection dylib to load
        test_targets: List of test targets to run
        **kwargs: Additional arguments
    """
    
    test_rules = []
    
    for test_target in test_targets:
        test_name = name + "_" + test_target
        injection_test(
            name = test_name,
            dylib = dylib,
            test_binary = test_target,
            **kwargs
        )
        test_rules.append(test_name)
    
    native.test_suite(
        name = name,
        tests = test_rules,
    )