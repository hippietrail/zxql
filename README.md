# ZXql Quick Look Extensions

macOS Quick Look extensions for 48K ZX Spectrum `.SNA` snapshot files.

## Features

- **Spacebar Preview**: Press spacebar on `.SNA` files to see full 256×192 decoded image
- **Finder Thumbnails**: File icons display decoded ZX Spectrum screenshots with correct aspect ratio

## Architecture

### Extensions

#### zxql-preview-extension
- **Type**: Quick Look Preview (spacebar)
- **Entry**: `PreviewViewController` (QLPreviewingController)
- **Function**: Renders 256×192 bitmap in preview panel
- **Note**: Uses UIKit coordinate system, full resolution display

#### zxql-thumbnail-extension  
- **Type**: Quick Look Thumbnail (Finder icons)
- **Entry**: `ThumbnailProvider` (QLThumbnailProvider)
- **Function**: Renders scaled thumbnail preserving 4:3 aspect ratio
- **Note**: Sandboxed XPC extension, scales to icon grid while maintaining aspect

### File Format

- **Extension**: `.SNA`
- **Size**: 49,179 bytes (fixed, 48K Spectrum snapshot)
- **Resolution**: 256×192 pixels (4:3 aspect ratio)
- **Memory Layout**: 
  - Bytes 0-26: Registers + state (27 bytes)
  - Bytes 27-6,910: Display memory (32×192 chars = 32×24 chars × 8 pixels)
  - Bytes 6,911-7,678: Attributes (color + brightness per char)

### Bitmap Decoding

The decoder reconstructs the ZX Spectrum display format:
1. Parse attribute bytes (ink color, paper color, brightness)
2. Iterate 24×32 character grid
3. For each character, unpack 8 pixel rows from display memory
4. Map bits to RGB using decoded color attributes
5. Handle Spectrum's "venetian blinds" memory layout (Y coordinate transformation)

## Implementation Decisions

### Key Challenges & Solutions

| Problem | Solution |
|---------|----------|
| No standard `.SNA` UTType | Declared custom `com.hippietrail.sna` in host app's Info.plist under `UTExportedTypeDeclarations` |
| Preview extension API | Used QLPreviewingController for spacebar; QLThumbnailProvider for icons |
| Two extensions in one target | Xcode requires separate targets; templates available for both |
| Shared decoding logic | Duplicated code in both extensions (only ~100 lines, acceptable for clarity) |
| Aspect ratio distortion | Calculate scale factor preserving 4:3 ratio; center in icon square |
| Extension binary missing | Swift files must be in target's "Compile Sources" build phase |
| Extensions not loading | Must install to `/Applications` (debug builds from Xcode don't work) |

### False Starts (for future reference)

❌ **Merged both extensions in one Info.plist array** → Broke preview functionality  
❌ **DRY refactoring with shared SnapshotDecoder.swift** → Module compilation errors  
❌ **Manual pbxproj editing** → Too fragile, UUID management errors  
❌ **Relied on file discovery** → Swift files need explicit Build Phase entry or Xcode won't compile  

## Build & Test

```bash
# Build both extensions
xcodebuild build -scheme zxql-host-app

# Reset Quick Look daemon
qlmanage -r

# Test spacebar preview
qlmanage -p /path/to/file.sna

# Or in Finder
open -a Finder /path/to/files
# Press spacebar on .sna file
# Thumbnails auto-display in icon view
```

## Installation

For system-wide use (not just development):
```bash
cp -r /path/to/zxql-host-app.app /Applications/
# Extensions load automatically
```

## Code Structure

```
zxql-host-app/
├── Info-generated.plist          # Declares com.hippietrail.sna UTType
└── AppDelegate.swift

zxql-preview-extension/
├── Info.plist                    # Preview extension config
├── PreviewViewController.swift    # QLPreviewingController subclass
├── Base.lproj/
│   └── PreviewViewController.xib # UI (ImageView)
└── *.swift                       # Support code & color decoding

zxql-thumbnail-extension/
├── Info.plist                    # Thumbnail extension config  
└── ThumbnailProvider.swift       # QLThumbnailProvider subclass
                                  # Contains: SNA decoder, color rendering
```

## Key Files Reference

- [zxql-preview-extension/Info.plist](zxql-preview-extension/Info.plist) - Declares `com.apple.quicklook.preview` extension point
- [zxql-preview-extension/PreviewViewController.swift](zxql-preview-extension/PreviewViewController.swift) - Spacebar preview implementation
- [zxql-thumbnail-extension/Info.plist](zxql-thumbnail-extension/Info.plist) - Declares `com.apple.quicklook.thumbnail` extension point
- [zxql-thumbnail-extension/ThumbnailProvider.swift](zxql-thumbnail-extension/ThumbnailProvider.swift) - Finder icon implementation
- [zxql-host-app/Info-generated.plist](zxql-host-app/Info-generated.plist) - UTType declaration for `.sna` files

## Future Reference: Creating Quick Look Extensions

**Checklist for new file type:**

1. [ ] Create custom UTType in host app's Info.plist
2. [ ] Add Preview Extension target (File > New > Target > macOS > Quick Look Preview Extension)
   - Implement `QLPreviewingController`
   - Add source files to Build Phases > Compile Sources
   - Configure Info.plist with `QLSupportedContentTypes`
3. [ ] Add Thumbnail Extension target (File > New > Target > macOS > Thumbnail Extension)
   - Implement `QLThumbnailProvider`
   - Add source files to Build Phases > Compile Sources
   - Configure Info.plist with `QLSupportedContentTypes` + `QLThumbnailMinimumDimension`
4. [ ] Test both via `qlmanage -r` and spacebar/Finder
5. [ ] Install to `/Applications/` for system-wide use

See [Apple Quick Look Thumbnailing docs](https://developer.apple.com/documentation/quicklookthumbnailing/providing-thumbnails-of-your-custom-file-types)
