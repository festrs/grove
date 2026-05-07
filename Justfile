# Grove iOS — Task Runner
# Usage: just <recipe>   |   just --list

# Find latest available iOS iPhone simulator dynamically
simulator := `xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime in sorted(data['devices'].keys(), reverse=True):
    if 'iOS' in runtime and 'xros' not in runtime.lower() and 'watch' not in runtime.lower() and 'tv' not in runtime.lower():
        for d in data['devices'][runtime]:
            if 'iPhone' in d['name']:
                print(d['udid'])
                sys.exit(0)
print('error: no iPhone simulator found', file=sys.stderr)
sys.exit(1)
"`

destination := "id=" + simulator

# Generate Xcode project from project.yml
generate:
    xcodegen generate

# Build the app
build: lint generate
    xcodebuild -scheme Grove -destination '{{destination}}' build

# Run unit tests
test: lint generate
    xcodebuild test -scheme Grove -destination '{{destination}}' -only-testing:GroveTests

# Run a specific test struct (e.g. just test-only RebalancingEngineTests)
test-only name: lint generate
    xcodebuild test -scheme Grove -destination '{{destination}}' -only-testing:GroveTests/{{name}}

# Run SwiftLint over the whole project
lint:
    swiftlint

# Alias: same as `just lint`
alias swiftlint := lint

# Run SwiftLint with auto-fix where safe
lint-fix:
    swiftlint --fix && swiftlint

# Run tests with coverage on, then print overall + per-file summary
coverage: generate
    #!/usr/bin/env bash
    set -euo pipefail
    BUNDLE=".coverage.xcresult"
    rm -rf "$BUNDLE"
    xcodebuild test \
        -scheme Grove \
        -destination '{{destination}}' \
        -only-testing:GroveTests \
        -enableCodeCoverage YES \
        -resultBundlePath "$BUNDLE" \
        -quiet
    echo ""
    echo "=== Overall coverage ==="
    xcrun xccov view --report --only-targets "$BUNDLE"
    echo ""
    echo "=== Lowest-covered files (top 30) ==="
    xcrun xccov view --report --files-for-target Grove.app "$BUNDLE" 2>/dev/null \
        | awk 'NR>2 && NF>=4 {print}' \
        | sort -k4 -n \
        | head -30

# Clean DerivedData
clean:
    rm -rf ~/Library/Developer/Xcode/DerivedData/Grove-*

# Clean and rebuild from scratch
rebuild: clean generate
    xcodebuild -scheme Grove -destination '{{destination}}' build

# Resolve SPM packages
resolve:
    xcodebuild -resolvePackageDependencies

# Show which simulator will be used
simulator:
    @xcrun simctl list devices available -j | python3 -c "\
    import json, sys; \
    data = json.load(sys.stdin); \
    found = [(runtime, d) for runtime in sorted(data['devices'].keys(), reverse=True) \
             if 'iOS' in runtime and 'xros' not in runtime.lower() and 'watch' not in runtime.lower() and 'tv' not in runtime.lower() \
             for d in data['devices'][runtime] if 'iPhone' in d['name']]; \
    r, d = found[0]; \
    print(f\"{d['name']} ({r.split('.')[-1]}) — {d['udid']}\")"

# --- Backend ---

# Rebuild and restart the backend
backend:
    cd ../project-fin && docker compose up -d --build backend

# Show current Cloudflare tunnel URL
tunnel:
    @docker logs project-fin-tunnel 2>&1 | grep "trycloudflare.com" | grep -v ERR | tail -1

# Restart Cloudflare tunnel (URL will change)
tunnel-restart:
    cd ../project-fin && docker compose restart cloudflared
    @sleep 2
    @docker logs project-fin-tunnel 2>&1 | grep "trycloudflare.com" | grep -v ERR | tail -1

# Run backend tests
backend-test:
    cd ../project-fin/backend && .venv312/bin/python -m pytest tests/ -v
