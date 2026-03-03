#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

NPROC=$(sysctl -n hw.ncpu)
CLEAN=false
SKIP_BUILD=false

for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=true ;;
    --skip-build) SKIP_BUILD=true ;;
    *) echo "Unknown option: $arg"; echo "Usage: $0 [--clean] [--skip-build]"; exit 1 ;;
  esac
done

PLATFORMS=(macos ios iossimulator maccatalyst)

if $CLEAN; then
  echo "=== Cleaning build directories ==="
  for p in "${PLATFORMS[@]}"; do
    rm -rf "build-${p}" "build-${p}-merged"
  done
  rm -rf build-xcframework
fi

# ── Build all platforms ──────────────────────────────────────────────────────

build_platform() {
  local name="$1" extra_args="$2"
  local build_dir="build-${name}"

  echo "=== Building ${name} arm64 ==="
  if [ ! -d "$build_dir" ]; then
    cmake -B "$build_dir" $extra_args \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  else
    echo "  (build dir exists, skipping configure)"
  fi
  cmake --build "$build_dir" -j"$NPROC"
}

if ! $SKIP_BUILD; then
  build_platform macos "-DBUILD_TOOLS=OFF"
  build_platform ios "-DCMAKE_TOOLCHAIN_FILE=cmake/ios.toolchain.cmake"
  build_platform iossimulator "-DCMAKE_TOOLCHAIN_FILE=cmake/iossimulator.toolchain.cmake"
  build_platform maccatalyst "-DCMAKE_TOOLCHAIN_FILE=cmake/maccatalyst.toolchain.cmake"
else
  echo "=== Skipping builds (--skip-build) ==="
fi

# ── Merge static libs ────────────────────────────────────────────────────────

merge_libs() {
  local name="$1"
  local build_dir="build-${name}"
  local merged_dir="build-${name}-merged"

  echo "=== Merging libs for ${name} ==="
  mkdir -p "$merged_dir"

  # Only use the top-level packed libs that cover all zvec symbols
  # without inter-library symbol overlap:
  #   - libzvec_db.a     — includes objects from common, index, sqlengine
  #   - libzvec_core.a   — independent (knn algorithms, index builders, metrics)
  #   - libzvec_ailego.a — independent (ailego utilities)
  #   - libzvec_proto.a  — protobuf generated code (db.a has a stub copy
  #                        with no symbol defs; proto.a has the real one)
  # Using all libzvec_*.a would cause duplicate symbols because CMake packs
  # transitive deps into each target (e.g., libzvec_db.a already contains
  # all objects from libzvec_common.a, libzvec_index.a, etc.)
  local zvec_libs=(
    "${build_dir}/lib/libzvec_db.a"
    "${build_dir}/lib/libzvec_core.a"
    "${build_dir}/lib/libzvec_ailego.a"
    "${build_dir}/lib/libzvec_proto.a"
  )

  if [ "$name" = "macos" ]; then
    # Strip Thrift SSL objects from arrow bundled deps to avoid OpenSSL
    # undefined symbols when linking with -all_load
    local arrow_src="${build_dir}/external/usr/local/lib/libarrow_bundled_dependencies.a"
    local arrow_clean="${merged_dir}/libarrow_bundled_dependencies_nothrift_ssl.a"
    cp "$arrow_src" "$arrow_clean"
    ar d "$arrow_clean" TSSLSocket.cpp.o 2>/dev/null || true
    ar d "$arrow_clean" TSSLServerSocket.cpp.o 2>/dev/null || true
    ar d "$arrow_clean" TWebSocketServer.cpp.o 2>/dev/null || true

    local ext_libs=()
    for f in "${build_dir}"/external/usr/local/lib/*.a; do
      [ "$(basename "$f")" = "libarrow_bundled_dependencies.a" ] && continue
      ext_libs+=("$f")
    done
    ext_libs+=("$arrow_clean")

    libtool -static -o "${merged_dir}/libzvec.a" "${zvec_libs[@]}" "${ext_libs[@]}"
  else
    libtool -static -o "${merged_dir}/libzvec.a" "${zvec_libs[@]}" "${build_dir}"/external/usr/local/lib/*.a
  fi

  echo "  -> ${merged_dir}/libzvec.a ($(du -h "${merged_dir}/libzvec.a" | cut -f1))"
}

for p in "${PLATFORMS[@]}"; do
  merge_libs "$p"
done

# ── Create XCFramework ───────────────────────────────────────────────────────

echo "=== Creating XCFramework ==="
rm -rf build-xcframework

xcodebuild -create-xcframework \
  -library build-ios-merged/libzvec.a -headers src/include \
  -library build-iossimulator-merged/libzvec.a -headers src/include \
  -library build-maccatalyst-merged/libzvec.a -headers src/include \
  -library build-macos-merged/libzvec.a -headers src/include \
  -output build-xcframework/zvec.xcframework

# ── Verify ────────────────────────────────────────────────────────────────────

echo ""
echo "=== Verification ==="
echo ""
echo "XCFramework contents:"
ls build-xcframework/zvec.xcframework/
echo ""

for p in "${PLATFORMS[@]}"; do
  merged="build-${p}-merged/libzvec.a"
  echo "--- ${p} ---"
  lipo -info "$merged"
done

echo ""
echo "✅ XCFramework built successfully at build-xcframework/zvec.xcframework"

