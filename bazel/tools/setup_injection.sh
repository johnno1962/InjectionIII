#!/bin/bash

# setup_injection.sh - Setup script for Bazel hot reload injection
#
# Created by Karim Alweheshy on 18/07/2025.
# Copyright © 2025 John Holdsworth. All rights reserved.
#
# This script sets up the necessary environment for hot reload injection
# with Bazel builds.

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly INJECTION_DIR="${WORKSPACE_ROOT}/bazel-bin/injection"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a Bazel workspace
check_bazel_workspace() {
    if [[ ! -f "${WORKSPACE_ROOT}/MODULE" && ! -f "${WORKSPACE_ROOT}/MODULE.bazel" ]]; then
        log_error "Not in a Bazel workspace. Please run this script from a Bazel workspace root."
        exit 1
    fi
    log_info "Found Bazel workspace at ${WORKSPACE_ROOT}"
}

# Check if Bazel is installed
check_bazel_installed() {
    if ! command -v bazel &> /dev/null; then
        log_error "Bazel is not installed. Please install Bazel first."
        exit 1
    fi
    log_info "Bazel is installed: $(bazel version | head -n 1)"
}

# Check if InjectionIII is available
check_injection_app() {
    local injection_app="/Applications/InjectionIII.app"
    if [[ ! -d "$injection_app" ]]; then
        log_warn "InjectionIII.app not found at $injection_app"
        log_warn "Please install InjectionIII.app for the best hot reload experience"
        return 1
    fi
    log_info "Found InjectionIII.app"
    return 0
}

# Set up injection build configuration
setup_build_config() {
    local bazelrc_file="${WORKSPACE_ROOT}/.bazelrc"
    local injection_bazelrc_file="${WORKSPACE_ROOT}/.injection.bazelrc"
    local injection_config="# Hot reload injection configuration
build:injection --compilation_mode=fastbuild
build:injection --features=swift.use_global_module_cache
build:injection --experimental_build_event_json_file_path_conversion=false
build:injection --linkopt=-interposable
build:injection --swiftcopt=-Xfrontend --swiftcopt=-enable-dynamic-replacement-chaining
build:injection --swiftcopt=-Xfrontend --swiftcopt=-enable-implicit-dynamic

# Enable build event protocol for injection
build:injection --build_event_json_file=/tmp/bazel_injection_bep.json
"

    # Create the .injection.bazelrc file
    log_info "Creating .injection.bazelrc with injection configuration"
    echo "$injection_config" > "$injection_bazelrc_file"

    # Add try-import to .bazelrc if it doesn't exist
    if [[ -f "$bazelrc_file" ]]; then
        if ! grep -q "try-import.*injection.bazelrc" "$bazelrc_file"; then
            log_info "Adding try-import to .bazelrc"
            echo "" >> "$bazelrc_file"
            echo "# Import injection configuration" >> "$bazelrc_file"
            echo "try-import %workspace%/.injection.bazelrc" >> "$bazelrc_file"
        else
            log_info "Try-import for injection configuration already exists in .bazelrc"
        fi
    else
        log_info "Creating .bazelrc with try-import for injection configuration"
        echo "# Import injection configuration" > "$bazelrc_file"
        echo "try-import %workspace%/.injection.bazelrc" >> "$bazelrc_file"
    fi
}

# Create injection directories
setup_directories() {
    mkdir -p "${INJECTION_DIR}"
    mkdir -p "${WORKSPACE_ROOT}/bazel-bin/hot_reload"
    log_info "Created injection directories"
}

# Create example BUILD file
create_example_build_file() {
    local example_dir="${WORKSPACE_ROOT}/examples/hot_reload"
    local build_file="${example_dir}/BUILD"
    
    if [[ ! -f "$build_file" ]]; then
        mkdir -p "$example_dir"
        cat > "$build_file" << 'EOF'
# Example BUILD file for hot reload injection

load("//bazel:hot_reload.bzl", "injection_enabled_swift_library", "create_injection_bundle")

# Example Swift library with hot reload capabilities
injection_enabled_swift_library(
    name = "ExampleLib",
    srcs = [
        "ExampleClass.swift",
        "ExampleViewController.swift",
    ],
    deps = [
        # Add your dependencies here
    ],
    visibility = ["//visibility:public"],
)

# Create an injection bundle for easy deployment
create_injection_bundle(
    name = "ExampleBundle",
    targets = ["ExampleLib"],
    visibility = ["//visibility:public"],
)
EOF

        # Create example Swift files
        cat > "${example_dir}/ExampleClass.swift" << 'EOF'
import Foundation

public class ExampleClass {
    public init() {}
    
    public func greet() -> String {
        return "Hello from ExampleClass!"
    }
    
    public func processData(_ input: String) -> String {
        return "Processed: \(input)"
    }
}
EOF

        cat > "${example_dir}/ExampleViewController.swift" << 'EOF'
import Foundation

public class ExampleViewController {
    public init() {}
    
    public func viewDidLoad() {
        print("ExampleViewController loaded")
    }
    
    public func handleButtonTap() {
        print("Button tapped!")
    }
}
EOF

        log_info "Created example hot reload project at ${example_dir}"
    fi
}

# Create workspace setup
setup_workspace() {
    local module_file="${WORKSPACE_ROOT}/MODULE.bazel"
    local injection_setup="
# Hot reload injection setup
bazel_dep(name = \"rules_swift\", version = \"1.0.0\")
bazel_dep(name = \"build_bazel_rules_apple\", version = \"3.0.0\")

# Add any additional module setup here
"

    if [[ -f "$module_file" ]]; then
        if ! grep -q "Hot reload injection setup" "$module_file"; then
            log_info "Adding injection setup to MODULE.bazel"
            echo "$injection_setup" >> "$module_file"
        else
            log_info "Injection setup already exists in MODULE.bazel"
        fi
    elif [[ -f "${WORKSPACE_ROOT}/MODULE" ]]; then
        local module_basic="${WORKSPACE_ROOT}/MODULE"
        if ! grep -q "Hot reload injection setup" "$module_basic"; then
            log_info "Adding injection setup to MODULE"
            echo "$injection_setup" >> "$module_basic"
        else
            log_info "Injection setup already exists in MODULE"
        fi
    fi
}

# Test the setup
test_setup() {
    log_info "Testing Bazel hot reload setup..."
    
    # Test basic Bazel query
    if bazel query "//..." &> /dev/null; then
        log_info "Bazel query test passed"
    else
        log_error "Bazel query test failed"
        return 1
    fi
    
    # Test if hot reload rules are available
    if bazel query "kind(rule, //bazel/tools:*)" &> /dev/null; then
        log_info "Hot reload tools are available"
    else
        log_warn "Hot reload tools not found, but basic setup is complete"
    fi
    
    return 0
}

# Print usage instructions
print_usage() {
    cat << 'EOF'

🎉 Bazel Hot Reload Setup Complete!

To use hot reload injection in your Bazel projects:

1. Use the hot reload macros in your BUILD files:
   ```
   load("//bazel:hot_reload.bzl", "injection_enabled_swift_library")
   
   injection_enabled_swift_library(
       name = "MyLib",
       srcs = ["MyClass.swift"],
   )
   ```

2. Build with injection configuration:
   ```
   bazel build --config=injection //path/to:your_target
   ```

3. Start your app with InjectionIII.app running, or use the hot reload
   server directly.

4. Edit your Swift files and they will be automatically recompiled and
   injected into your running app!

For more examples, see the examples/hot_reload directory.

EOF
}

# Main function
main() {
    log_info "Setting up Bazel hot reload injection..."
    
    check_bazel_workspace
    check_bazel_installed
    check_injection_app || true  # Don't fail if InjectionIII.app is not found
    
    setup_build_config
    setup_directories
    setup_workspace
    create_example_build_file
    
    if test_setup; then
        log_info "Setup completed successfully!"
        print_usage
    else
        log_error "Setup completed with warnings. Please check the output above."
        exit 1
    fi
}

# Run main function
main "$@"