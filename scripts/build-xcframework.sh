#!/usr/bin/env bash
# Build zvec XCFramework for iOS, iOS Simulator, Mac Catalyst, and macOS.
# No set -e: we check errors explicitly where they matter.
set -uo pipefail

cd "$(dirname "$0")/.."

# ── Helpers ──────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

ok()  { printf "${GREEN}✅ %s${RESET}\n" "$*"; }
err() { printf "${RED}❌ %s${RESET}\n" "$*" >&2; }

usage() {
  cat <<EOF
Usage: build-xcframework.sh [OPTIONS]
  --clean         Remove all build dirs before building
  --skip-build    Skip cmake builds (just merge + package)
  --verify        Run swift test after building
  --publish       Publish to GitHub (requires --version)
  --version=TAG   Release version tag (e.g., v0.3.0-ios)
  --help          Show this help
EOF
}

# ── Parse args ───────────────────────────────────────────────────────────────

NPROC=$(sysctl -n hw.ncpu)
CLEAN=false
SKIP_BUILD=false
PUBLISH=false
VERIFY=false
VERSION=""

for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=true ;;
    --skip-build) SKIP_BUILD=true ;;
    --publish) PUBLISH=true ;;
    --verify) VERIFY=true ;;
    --version=*) VERSION="${arg#--version=}" ;;
    --help) usage; exit 0 ;;
    *) err "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

if $PUBLISH && [ -z "$VERSION" ]; then
  err "--publish requires --version=TAG (e.g. --version=v0.2.0-ios)"
  exit 1
fi

PLATFORMS=(macos ios iossimulator maccatalyst)

# The 4 curated zvec libs — these are the top-level packed libs that cover
# all zvec symbols without inter-library overlap. Do NOT glob lib/*.a:
# component libs (libcore_*.a, libzvec_common.a, etc.) are already packed
# into libzvec_core.a / libzvec_db.a and would cause duplicate symbols
# with -all_load.
ZVEC_LIBS=(libzvec_db.a libzvec_core.a libzvec_ailego.a libzvec_proto.a)

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

  # cmake --build may fail on dylib targets (missing CoreFoundation for
  # cross-compiled platforms). That's expected — we only need the .a files.
  cmake --build "$build_dir" -j"$NPROC" || true

  # Validate that all required static libs were produced
  local missing=false
  for lib in "${ZVEC_LIBS[@]}"; do
    if [ ! -f "${build_dir}/lib/${lib}" ]; then
      err "${build_dir}/lib/${lib} not found — ${name} build failed"
      missing=true
    fi
  done
  if $missing; then
    exit 1
  fi
  ok "${name} build complete"
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

  # Build the curated zvec libs list with full paths
  local zvec_lib_paths=()
  for lib in "${ZVEC_LIBS[@]}"; do
    zvec_lib_paths+=("${build_dir}/lib/${lib}")
  done

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

    libtool -static -o "${merged_dir}/libzvec.a" "${zvec_lib_paths[@]}" "${ext_libs[@]}"
  else
    libtool -static -o "${merged_dir}/libzvec.a" "${zvec_lib_paths[@]}" "${build_dir}"/external/usr/local/lib/*.a
  fi

  if [ ! -f "${merged_dir}/libzvec.a" ]; then
    err "Failed to create ${merged_dir}/libzvec.a"
    exit 1
  fi
  ok "${name} merged ($(du -h "${merged_dir}/libzvec.a" | cut -f1))"
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

if [ ! -d "build-xcframework/zvec.xcframework" ]; then
  err "xcodebuild failed to create XCFramework"
  exit 1
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "=== XCFramework contents ==="
ls build-xcframework/zvec.xcframework/
echo ""

for p in "${PLATFORMS[@]}"; do
  merged="build-${p}-merged/libzvec.a"
  echo "--- ${p} ---"
  lipo -info "$merged"
done

echo ""
ok "XCFramework built at build-xcframework/zvec.xcframework"

# ── Switch Package.swift to local path (unless --publish) ────────────────────

if ! $PUBLISH; then
  echo ""
  echo "=== Switching Package.swift to local XCFramework path ==="
  awk '
    /\.binaryTarget\(/ { in_bt=1 }
    in_bt && /\),/ {
      printf "        .binaryTarget(\n"
      printf "            name: \"zvec\",\n"
      printf "            path: \"build-xcframework/zvec.xcframework\"\n"
      printf "        ),\n"
      in_bt=0; next
    }
    !in_bt { print }
  ' Package.swift > Package.swift.tmp && mv Package.swift.tmp Package.swift
  rm -rf .build/artifacts
  ok "Package.swift set to local path"
fi

# ── Verify (--verify) ───────────────────────────────────────────────────────

if $VERIFY; then
  echo ""
  echo "=== Running swift test ==="
  rm -rf .build/artifacts
  swift package clean
  if swift test 2>&1; then
    ok "All tests passed"
  else
    err "swift test failed"
    exit 1
  fi
fi

# ── Publish ──────────────────────────────────────────────────────────────────

if $PUBLISH; then
  echo ""
  echo "=== Publishing XCFramework as GitHub release ${VERSION} ==="

  if ! command -v gh &>/dev/null; then
    err "gh CLI is not installed. Install from https://cli.github.com/"
    exit 1
  fi

  if ! gh auth status &>/dev/null 2>&1; then
    err "gh CLI is not authenticated. Run 'gh auth login' first."
    exit 1
  fi

  # Step 1: Zip
  echo "--- Zipping XCFramework ---"
  (cd build-xcframework && zip -r zvec.xcframework.zip zvec.xcframework)
  echo "  -> build-xcframework/zvec.xcframework.zip"

  # Step 2: Compute checksum
  echo "--- Computing checksum ---"
  CHECKSUM=$(swift package compute-checksum build-xcframework/zvec.xcframework.zip)
  echo "  -> checksum: ${CHECKSUM}"

  # Step 3: Create GitHub release
  echo "--- Creating GitHub release ${VERSION} ---"
  STRIP_V="${VERSION#v}"
  gh release create "$VERSION" \
    --title "iOS XCFramework ${STRIP_V}" \
    --prerelease \
    --notes "Release ${VERSION}" \
    build-xcframework/zvec.xcframework.zip
  echo "  -> release created"

  # Step 4: Update Package.swift with remote URL
  echo "--- Updating Package.swift ---"
  REPO_URL=$(gh repo view --json url -q .url)
  DOWNLOAD_URL="${REPO_URL}/releases/download/${VERSION}/zvec.xcframework.zip"

  # Replace the binaryTarget block (handles both local path and remote url forms)
  awk -v url="$DOWNLOAD_URL" -v cs="$CHECKSUM" '
    /\.binaryTarget\(/ { in_bt=1 }
    in_bt && /\),/ {
      printf "        .binaryTarget(\n"
      printf "            name: \"zvec\",\n"
      printf "            url: \"%s\",\n", url
      printf "            checksum: \"%s\"\n", cs
      printf "        ),\n"
      in_bt=0; next
    }
    !in_bt { print }
  ' Package.swift > Package.swift.tmp && mv Package.swift.tmp Package.swift

  echo "  -> Package.swift updated"

  # Step 5: Commit and push
  echo "--- Committing and pushing ---"
  git add Package.swift
  git commit -m "chore: publish XCFramework ${VERSION}"
  git push

  echo ""
  ok "Published ${VERSION} successfully"
  REPO_URL=$(gh repo view --json url -q .url)
  echo "   Release: ${REPO_URL}/releases/tag/${VERSION}"
fi

