# Bazel Hot Reload Integration

This document describes the comprehensive Bazel integration for InjectionIII hot reload functionality.

## Overview

The Bazel integration provides seamless hot reload support for iOS and macOS applications built with Bazel. It maintains full backward compatibility with existing Xcode-based workflows while adding powerful new capabilities for Bazel-based development.

## Features

### Core Integration
- **Dual Build System Support**: Automatically detects and switches between Xcode and Bazel builds
- **Build Event Protocol (BEP) Integration**: Parses Bazel's BEP streams for compilation commands and outputs
- **Async Processing**: Non-blocking Bazel builds and file watching for optimal performance
- **Intelligent Caching**: Source-to-target mapping with performance optimization

### Bazel Rules System
- **`hot_reload_wrapper`**: Easy-to-use macro for existing Swift libraries
- **`injection_enabled_swift_library`**: Pre-configured libraries with injection support
- **`create_injection_bundle`**: Bundles dylibs for deployment
- **Platform Support**: iOS simulator, iOS device, and macOS configurations

### Developer Experience
- **Auto-Detection**: Automatically detects Bazel workspaces
- **Zero Configuration**: Works out-of-the-box with existing Bazel projects
- **Performance Monitoring**: Built-in metrics and debugging support
- **Comprehensive Error Handling**: Graceful fallbacks and clear error messages

## Quick Start

### 1. Setup Your Bazel Workspace

```bash
# Run the setup script
./bazel/tools/setup_injection.sh
```

### 2. Update Your BUILD Files

```python
load("//bazel:hot_reload.bzl", "injection_enabled_swift_library")

injection_enabled_swift_library(
    name = "MyApp",
    srcs = ["Sources/MyApp.swift"],
    deps = ["//common:SharedCode"],
)
```

### 3. Build and Run

```bash
# Build with injection support
bazel build --config=injection //ios:MyApp

# Run your app with InjectionIII.app
```

### 4. Start Developing

- Edit your Swift files
- Save changes
- Watch them automatically inject into your running app!

## Architecture

### Core Components

1. **BazelBuildEventParser**: Parses BEP JSON streams to extract compilation commands
2. **BazelInterface**: Manages Bazel queries, builds, and target discovery
3. **BazelFileWatcher**: Intelligent file monitoring with target mapping
4. **SwiftEval**: Enhanced with Bazel build system support
5. **InjectionServer**: Integrated Bazel workspace detection and processing

### Integration Points

- **Client Detection**: Automatic Bazel workspace detection in app initialization
- **Server Processing**: Bazel-aware file watching and build processing
- **Build Rules**: Comprehensive Bazel rules for hot reload dylib generation
- **Tooling**: Python-based compiler and shell setup scripts

## Configuration

### .bazelrc Configuration

The setup script automatically adds the following configuration:

```bash
# Hot reload injection configuration
build:injection --compilation_mode=fastbuild
build:injection --features=swift.use_global_module_cache
build:injection --linkopt=-interposable
build:injection --swiftcopt=-Xfrontend --swiftcopt=-enable-dynamic-replacement-chaining
build:injection --build_event_json_file=/tmp/bazel_injection_bep.json
```

### Environment Variables

- `INJECTION_BAZEL_WORKSPACE`: Path to detected Bazel workspace
- `INJECTION_BAZEL_MODE`: Enables Bazel-specific injection behavior

## Advanced Usage

### Custom Hot Reload Rules

```python
hot_reload_dylib(
    name = "my_custom_dylib",
    source = "MyClass.swift",
    deps = [":MyLibrary"],
    module_name = "MyModule",
)
```

### Injection Bundles

```python
create_injection_bundle(
    name = "MyAppBundle",
    targets = ["MyApp", "MyLibrary"],
)
```

### Platform-Specific Libraries

```python
ios_injection_library(
    name = "MyiOSLib",
    srcs = ["ios_specific.swift"],
)

macos_injection_library(
    name = "MyMacLib", 
    srcs = ["macos_specific.swift"],
)
```

## Performance

The Bazel integration includes several performance optimizations:

- **Incremental Builds**: Leverages Bazel's incremental build capabilities
- **Target Caching**: Caches source-to-target mappings for fast lookups
- **Async Processing**: Non-blocking build operations
- **BEP Streaming**: Efficient parsing of build event streams

## Troubleshooting

### Common Issues

1. **Bazel Not Found**: Ensure Bazel is installed and in PATH
2. **Workspace Detection**: Verify WORKSPACE file exists in project root
3. **Build Failures**: Check that targets have proper dependencies
4. **Injection Failures**: Ensure `-interposable` linker flag is set

### Debug Mode

Enable debug logging with:
```bash
export INJECTION_DEBUG=1
```

## Migration Guide

### From Xcode to Bazel

1. Keep existing InjectionIII.app setup
2. Add Bazel rules to your BUILD files
3. Use `hot_reload_wrapper` for existing libraries
4. No code changes required in Swift files

### Hybrid Workflows

The integration supports hybrid workflows where some targets use Bazel and others use Xcode. The system automatically detects and switches between build systems as needed.

## Contributing

When contributing to the Bazel integration:

1. Follow existing code patterns and naming conventions
2. Add tests for new functionality
3. Update documentation for new features
4. Ensure backward compatibility with Xcode workflows

## License

This integration is released under the same license as InjectionIII.