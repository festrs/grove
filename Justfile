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
build: generate
    xcodebuild -scheme Grove -destination '{{destination}}' build

# Run unit tests
test: generate
    xcodebuild test -scheme Grove -destination '{{destination}}' -only-testing:GroveTests

# Run a specific test struct (e.g. just test-only RebalancingEngineTests)
test-only name: generate
    xcodebuild test -scheme Grove -destination '{{destination}}' -only-testing:GroveTests/{{name}}

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
