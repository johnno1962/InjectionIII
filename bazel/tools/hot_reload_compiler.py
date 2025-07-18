#!/usr/bin/env python3
"""
Hot reload compiler tool for Bazel.

This tool compiles Swift source files into dynamic libraries suitable for
hot reload injection.

Created by Karim Alweheshy on 18/07/2025.
Copyright © 2025 John Holdsworth. All rights reserved.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import List, Optional


class HotReloadCompiler:
    """Compiles Swift source files into hot reload dynamic libraries."""
    
    def __init__(self):
        self.swift_compiler = self._find_swift_compiler()
        
    def _find_swift_compiler(self) -> str:
        """Find the Swift compiler executable."""
        # Try to find swiftc in common locations
        possible_paths = [
            "/usr/bin/swiftc",
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc",
            "/Library/Developer/CommandLineTools/usr/bin/swiftc",
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                return path
        
        # Try to find it in PATH
        try:
            result = subprocess.run(["which", "swiftc"], 
                                  capture_output=True, text=True, check=True)
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            raise RuntimeError("Could not find Swift compiler (swiftc)")
    
    def compile_hot_reload_dylib(self,
                                source_file: str,
                                output_file: str,
                                module_name: str,
                                target_triple: str,
                                sdk_path: str,
                                deps: List[str] = None,
                                extra_flags: List[str] = None) -> None:
        """Compile a Swift source file into a hot reload dylib."""
        
        if deps is None:
            deps = []
        if extra_flags is None:
            extra_flags = []
        
        # Build the Swift compiler command
        cmd = [
            self.swift_compiler,
            "-frontend",
            "-emit-library",
            "-o", output_file,
            "-module-name", module_name,
            "-target", target_triple,
            "-sdk", sdk_path,
        ]
        
        # Add dependency paths
        for dep in deps:
            if os.path.exists(dep):
                if dep.endswith(".swiftmodule"):
                    cmd.extend(["-I", os.path.dirname(dep)])
                elif dep.endswith(".framework"):
                    cmd.extend(["-F", os.path.dirname(dep)])
        
        # Add linker flags for dynamic library
        cmd.extend([
            "-Xlinker", "-dylib",
            "-Xlinker", "-interposable",
            "-Xlinker", "-undefined",
            "-Xlinker", "dynamic_lookup",
        ])
        
        # Enable hot reload features
        cmd.extend([
            "-Xfrontend", "-enable-dynamic-replacement-chaining",
            "-Xfrontend", "-enable-implicit-dynamic",
        ])
        
        # Add extra flags
        cmd.extend(extra_flags)
        
        # Add the source file
        cmd.append(source_file)
        
        # Run the compiler
        print(f"Compiling {source_file} -> {output_file}")
        print(f"Command: {' '.join(cmd)}")
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            if result.stdout:
                print(result.stdout)
        except subprocess.CalledProcessError as e:
            print(f"Compilation failed: {e}")
            if e.stdout:
                print(f"stdout: {e.stdout}")
            if e.stderr:
                print(f"stderr: {e.stderr}")
            sys.exit(1)
    
    def create_injection_bundle(self,
                               dylib_files: List[str],
                               bundle_path: str) -> None:
        """Create an injection bundle from dylib files."""
        
        bundle_dir = Path(bundle_path)
        bundle_dir.mkdir(parents=True, exist_ok=True)
        
        for dylib_file in dylib_files:
            dylib_path = Path(dylib_file)
            if dylib_path.exists():
                import shutil
                shutil.copy2(dylib_path, bundle_dir / dylib_path.name)
                print(f"Added {dylib_path.name} to bundle")
        
        print(f"Created injection bundle: {bundle_path}")


def main():
    """Main entry point for the hot reload compiler tool."""
    
    parser = argparse.ArgumentParser(
        description="Compile Swift source files into hot reload dynamic libraries"
    )
    
    parser.add_argument("--source", required=True,
                       help="Swift source file to compile")
    parser.add_argument("--output", required=True,
                       help="Output dylib file path")
    parser.add_argument("--module-name", required=True,
                       help="Swift module name")
    parser.add_argument("--target", 
                       default="x86_64-apple-macosx10.15",
                       help="Target triple")
    parser.add_argument("--sdk",
                       default="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk",
                       help="SDK path")
    parser.add_argument("--dep", action="append", default=[],
                       help="Dependency file (can be specified multiple times)")
    parser.add_argument("--extra-flag", action="append", default=[],
                       help="Extra compiler flag (can be specified multiple times)")
    parser.add_argument("--bundle", 
                       help="Create injection bundle at this path")
    parser.add_argument("--verbose", "-v", action="store_true",
                       help="Enable verbose output")
    
    args = parser.parse_args()
    
    if args.verbose:
        print(f"Hot reload compiler starting...")
        print(f"Source: {args.source}")
        print(f"Output: {args.output}")
        print(f"Module: {args.module_name}")
        print(f"Target: {args.target}")
        print(f"SDK: {args.sdk}")
        print(f"Dependencies: {args.dep}")
    
    # Create the compiler
    compiler = HotReloadCompiler()
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    
    # Compile the dylib
    try:
        compiler.compile_hot_reload_dylib(
            source_file=args.source,
            output_file=args.output,
            module_name=args.module_name,
            target_triple=args.target,
            sdk_path=args.sdk,
            deps=args.dep,
            extra_flags=args.extra_flag
        )
        
        print(f"Successfully compiled {args.source} -> {args.output}")
        
        # Create bundle if requested
        if args.bundle:
            compiler.create_injection_bundle([args.output], args.bundle)
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()