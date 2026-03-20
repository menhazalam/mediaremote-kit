# MediaRemoteAdapter Build Instructions

## Build the framework

Run these commands in Terminal:

```bash
cd repos/mediaremote-adapter
mkdir -p build && cd build
cmake ..
cmake --build .
```

## Copy built files to this directory

After building, copy these files here:

```bash
cp build/MediaRemoteAdapter.framework MacConnect/MacConnect/Resources/MediaRemoteAdapter/
cp build/MediaRemoteAdapterTestClient MacConnect/MacConnect/Resources/MediaRemoteAdapter/
```

## Files needed in this directory

- `mediaremote-adapter.pl` (already copied)
- `MediaRemoteAdapter.framework/` (you need to build and copy)
- `MediaRemoteAdapterTestClient` (you need to build and copy)

## After copying

Add all files to Xcode:
1. Right-click on `MacConnect/Resources/MediaRemoteAdapter` in Xcode
2. Select "Add Files to MacConnect..."
3. Select all three items
4. Make sure "Copy items if needed" is UNCHECKED (they're already in the right place)
5. Make sure "Create folder references" is selected
6. Add to target: MacConnect
