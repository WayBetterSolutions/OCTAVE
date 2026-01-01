#!/usr/bin/env python3
"""
Compile Android Auto Protocol Buffer definitions to Python modules.

This script compiles all .proto files from the aasdk library into
Python modules that can be used by OCTAVE's Android Auto implementation.
"""

import os
import sys
import subprocess
from pathlib import Path


def compile_protos():
    """Compile all AAP protobuf files to Python."""

    # Paths
    base_dir = Path(__file__).parent.parent.parent
    aasdk_proto_dir = base_dir / "android_auto" / "aasdk" / "protobuf"
    output_dir = Path(__file__).parent / "proto"

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Create __init__.py for proto package
    (output_dir / "__init__.py").write_text('"""Generated Protocol Buffer modules for Android Auto Protocol."""\n')

    if not aasdk_proto_dir.exists():
        print(f"Error: aasdk protobuf directory not found at {aasdk_proto_dir}")
        print("Please run: git clone https://github.com/opencardev/aasdk.git android_auto/aasdk")
        return False

    # Find all .proto files
    proto_files = list(aasdk_proto_dir.rglob("*.proto"))

    if not proto_files:
        print("No .proto files found!")
        return False

    print(f"Found {len(proto_files)} proto files to compile...")

    # Compile using grpcio-tools
    # We need to set the include paths correctly
    include_paths = [
        str(aasdk_proto_dir),
        str(aasdk_proto_dir / "aap_protobuf"),
    ]

    # Build the protoc command
    python_exe = sys.executable

    compiled = 0
    errors = 0

    for proto_file in proto_files:
        try:
            # Use python -m grpc_tools.protoc
            cmd = [
                python_exe, "-m", "grpc_tools.protoc",
                f"--proto_path={aasdk_proto_dir}",
                f"--python_out={output_dir}",
                str(proto_file)
            ]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=str(base_dir)
            )

            if result.returncode == 0:
                compiled += 1
                print(f"  OK: {proto_file.name}")
            else:
                errors += 1
                print(f"  FAIL: {proto_file.name}: {result.stderr.strip()}")

        except Exception as e:
            errors += 1
            print(f"  FAIL: {proto_file.name}: {e}")

    print(f"\nCompilation complete: {compiled} succeeded, {errors} failed")

    # Create helper imports
    create_proto_imports(output_dir)

    return errors == 0


def create_proto_imports(output_dir: Path):
    """Create convenient import modules for the generated protos."""

    # Find all generated _pb2.py files
    pb2_files = list(output_dir.rglob("*_pb2.py"))

    if not pb2_files:
        print("No generated files found to create imports for.")
        return

    # Group by service type
    services = {
        "control": [],
        "media": [],
        "input": [],
        "sensor": [],
        "bluetooth": [],
        "navigation": [],
        "phone": [],
        "other": [],
    }

    for pb2_file in pb2_files:
        rel_path = pb2_file.relative_to(output_dir)
        module_path = str(rel_path.with_suffix("")).replace(os.sep, ".")

        # Categorize
        path_str = str(rel_path).lower()
        if "control" in path_str:
            services["control"].append(module_path)
        elif "media" in path_str or "video" in path_str or "audio" in path_str:
            services["media"].append(module_path)
        elif "input" in path_str:
            services["input"].append(module_path)
        elif "sensor" in path_str:
            services["sensor"].append(module_path)
        elif "bluetooth" in path_str:
            services["bluetooth"].append(module_path)
        elif "navigation" in path_str:
            services["navigation"].append(module_path)
        elif "phone" in path_str:
            services["phone"].append(module_path)
        else:
            services["other"].append(module_path)

    print(f"\nGenerated proto modules by category:")
    for category, modules in services.items():
        if modules:
            print(f"  {category}: {len(modules)} modules")


if __name__ == "__main__":
    success = compile_protos()
    sys.exit(0 if success else 1)
