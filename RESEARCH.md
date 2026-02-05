# Research: UTType Size-Based Filtering for .sna Files

## Problem Statement
`com.hippietrail.sna` UTType currently matches ANY `.sna` file, regardless of size or format. The `.sna` extension is used by **at least three completely different emulator systems**:

### ZX Spectrum Snapshots
- **48K Spectrum**: 49,179 bytes (fixed, unique) ← **Our target**
  - No magic bytes identifier
  - Single definitive file size = primary discriminator
  - Heuristics: Check for illegal byte ranges in Z80 registers, undefined bits
- **128K Spectrum**: Multiple possible sizes (49,913+ bytes, variable)
  - Also no magic bytes
  - Multiple possible file lengths (makes size-based detection ambiguous)

### Amstrad CPC Snapshots
- **64K CPC**: 100+ bytes header + 64,000+ bytes RAM
- **128K CPC 6128**: 100+ bytes header + 128,000+ bytes RAM
- **Version 3 with chunks**: Variable size with tagged chunks (newer format)
- Starts with magic bytes `MV - SNA` (not just file size)
- [Full spec here](https://www.cpcwiki.eu/index.php/Format:SNA_snapshot_file_format)

### Tom Ehlert Drive Snapshot (DOS/Windows)
- Disk image backup format (not emulator snapshot)
- Variable size (full disk image to gigabytes)
- Binary backup of Windows/DOS partitions
- [Website](http://www.drivesnapshot.de/en/)

**Key insight**: These aren't just size variations—they're **fundamentally different file formats**:
- **Amstrad CPC**: Has magic bytes ("MV - SNA"), easily identified
- **ZX Spectrum**: NO magic bytes; relies on file size and heuristics
- **48K Spectrum**: Single, unique file size (49,179 bytes) = definitive identifier ✓
- **128K Spectrum**: Multiple possible sizes = ambiguous
- **Drive Snapshot**: Variable size backup format = completely different use case

For our Quick Look extension: We check the exact file size of 49,179 bytes. This is the **only unambiguous identifier** for 48K Spectrum snapshots and reliably distinguishes from all other .sna variants.

## Key Findings

### 1. **UTType Has NO Built-In Size Filtering**
Apple's official UTType documentation shows:
- `UTTypeTagSpecification` can define extensions and MIME types
- `UTTypeConformsTo` can define type hierarchy
- **No mechanism to filter by file size or custom properties**

Sources:
- [Apple: Defining file and data types](https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app)
- The official API only supports: identifier, extension, MIME type, conformance, description

### 2. **Multiple Extensions for One Type IS Possible**
UTType DOES support multiple file extensions in a single type:
```xml
<key>UTTypeTagSpecification</key>
<dict>
    <key>public.filename-extension</key>
    <array>
        <string>sna</string>
        <string>snap</string>
        <string>snapshot</string>
    </array>
</dict>
```

But this is the opposite of what we need (one extension, multiple types).

### 3. **Real-World Approach: Multiple UTTypes for Same Extension**
**Solution confirmed in ZX Spectrum ecosystem:**

From [zx-evo repository](https://github.com/tslabs/zx-evo):
- `.sna` is used for multiple snapshot formats
- Emulators validate file size/format at runtime
- No UTType-level discrimination—validation happens in app code

From [Unreal Speccy Portable](https://github.com/djdron/UnrealSpeccyP) (major Spectrum emulator):
- Lists supported formats: SNA, Z80, SZX, TZX, TAP, etc.
- **Validates file format after user selects file**
- No mention of UTType-based filtering

### 4. **macOS Extension Behavior**
When a UTType fails its extension check:
- Quick Look extensions receive the file
- Extension can then validate and reject (returning error)
- System falls back to default handlers

**Our current implementation:** ✅ Already doing this correctly
- We reject invalid files silently  
- macOS uses other handlers

## Viable Approaches

### ❌ Approach 1: Multiple UTTypes (Won't Work)
Define separate UTTypes like:
- `com.hippietrail.sna.48k` (size = 49179)
- `com.hippietrail.sna.128k` (size = 49913+)

**Problem:** Can't declare the same extension twice in Info.plist (causes conflicts)

### ❌ Approach 2: File Content Type Sniffing
Add a custom content type based on magic bytes:
```xml
<key>public.mime-type</key>
<array>
    <string>application/x-spectrum-48k-snapshot</string>
</array>
```

**Problem:** Extension isn't determined by content bytes for .sna files—macOS still matches by extension first.

### ✅ Approach 3: Size-Based Wrapper UTType (RECOMMENDED)
Create a **wrapper UTType** that conforms to `public.data` but is more specific:

```xml
<dict>
    <key>UTTypeIdentifier</key>
    <string>com.hippietrail.sna.48k</string>
    <key>UTTypeConformsTo</key>
    <array>
        <string>com.hippietrail.sna</string>
    </array>
    <key>UTTypeTagSpecification</key>
    <dict>
        <key>public.filename-extension</key>
        <array>
            <string>sna</string>
        </array>
    </dict>
    <!-- Add metadata for documentation -->
    <key>UTTypeReferenceURL</key>
    <string>https://sinclair.wiki.zxnet.co.uk/wiki/SNA_snapshot_format</string>
</dict>
```

Then configure extensions to declare support for the **more specific** type:
- `zxql-preview-extension/Info.plist`: `com.hippietrail.sna.48k`
- `zxql-thumbnail-extension/Info.plist`: `com.hippietrail.sna.48k`

Extensions would still validate at runtime (already doing this).

**Advantage:** Signal to the system which .sna variant we handle  
**Current behavior:** Still works the same (silent rejection)

### ✅ Approach 4: Accept Current Design (PRAGMATIC)
**Status quo is fine because:**
1. ✅ We silently reject invalid files (no error images)
2. ✅ macOS falls back to default Finder preview
3. ✅ Runtime validation prevents crashes
4. ✅ Matches how other emulators handle it (Fuse, Unreal Speccy, JVGS)

Only drawback: All .sna files (48K and 128K) trigger our extension, even if we only handle 48K.

## Why Size-Based Validation Works for 48K Spectrum

The 48K Spectrum .sna format is **uniquely identifiable by file size alone**:
- **49,179 bytes** = always 48K Spectrum (unambiguous across all systems)
- No magic bytes, so file size is the primary discriminator
- Checking exact length is more reliable than heuristics for our use case

This is why our implementation is correct:
```swift
guard data.count == 49179 else {
    throw NSError(...)  // Silently reject
}
```

We're leveraging the one definitive property that identifies 48K Spectrum files.

## Recommendation

**Keep Approach 4 (Current Design)** as documented in this codebase:

✅ **What we're doing RIGHT:**
1. **Exact size check** - 49,179 bytes = unambiguous 48K Spectrum identifier
2. **Silent rejection** - Invalid files don't generate error images
3. **Graceful fallback** - macOS uses other handlers for other .sna variants
4. **Matches industry practice** - Emulators (Fuse, Unreal Speccy) validate at runtime
5. **Future-proof** - User can install other Quick Look extensions for Amstrad/128K without conflicts

❌ **Why NOT implement filtering at UTType level:**
- UTType is a **type declaration**, not a **validation mechanism**
- Apple UTType spec has no mechanism for size constraints
- Attempting to discriminate at UTType level would require either:
  - Separate UTType per variant → breaks multi-handler scenarios
  - Encoded magic bytes → but Spectrum format has none
- File size cannot be verified before extension loads
- Runtime validation at extension load time is the **most reliable approach**

**Bottom line:** Current implementation is optimal. Size-checking at runtime is:
- ✅ Unambiguous (49,179 = only 48K Spectrum)
- ✅ Reliable (happens at load time, not system level)
- ✅ User-friendly (silent rejection, no error clutter)
- ✅ Extensible (other handlers can coexist)

## References
- [Apple UTType API](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct)
- [Apple defining types guide](https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app)
- [ZX Spectrum snapshot formats (wiki)](https://sinclair.wiki.zxnet.co.uk/wiki/SNA_snapshot_format)
- [Fuse emulator (supports multiple .sna variants)](http://fuse-emulator.sourceforge.net/)
- [Unreal Speccy Portable (ZX Spectrum emulator)](https://github.com/djdron/UnrealSpeccyP)
