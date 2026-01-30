//
//  PreviewViewController.swift
//  zxql-preview-extension
//
//  Created by Andrew Dunbar on 29/1/2026.
//

import Cocoa
import Quartz
import UniformTypeIdentifiers

extension RandomAccessCollection {
    /// Retrieve a single element from a collection by offset (like Rust, Go, etc.)
    /// - Parameter offset: Offset from start of collection
    /// - Returns: Element at that offset
    subscript(o offset: Int) -> Element {
        return self[index(startIndex, offsetBy: offset)]
    }

    /// Retrieve a sub-collection by offset and length (like Rust, Go, etc.)
    /// - Parameter offset: Offset from start of collection
    /// - Parameter length: Number of elements to retrieve
    /// - Returns: Sub-collection (slice) of specified length
    subscript(o offset: Int, l length: Int) -> SubSequence {
        let startIndex = self.index(self.startIndex, offsetBy: offset)
        let endIndex = self.index(startIndex, offsetBy: length)
        return self[startIndex..<endIndex]
    }

    /// Retrieve a sub-collection by start and end offset (like Rust, Go, etc.)
    /// - Parameter offset: Offset from start of collection
    /// - Parameter endOffset: End offset from start of collection
    /// - Returns: Sub-collection (slice) from offset to endOffset
    subscript(o offset: Int, e endOffset: Int) -> SubSequence {
        let startIndex = self.index(self.startIndex, offsetBy: offset)
        let endIndex = self.index(self.startIndex, offsetBy: endOffset)
        return self[startIndex..<endIndex]
    }
}

class PreviewViewController: NSViewController, QLPreviewingController {
    @IBOutlet weak var imageView: NSImageView?

    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    override func loadView() {
        super.loadView()
    }

    func preparePreviewOfFile(at url: URL) async throws {
        do {
            let data = try Data(contentsOf: url)
            
            // Validate file size
            guard data.count == 49179 else {
                throw NSError(domain: "PreviewViewController", code: -1, 
                             userInfo: [NSLocalizedDescriptionKey: "Invalid .sna file size: \(data.count) bytes"])
            }
            
            // Create bitmap image
            let image = decodeSnapshotData(data)
            
            DispatchQueue.main.async {
                if let imageView = self.imageView {
                    imageView.image = image
                    imageView.imageScaling = .scaleProportionallyUpOrDown
                }
            }
        } catch {
            let errorImage = createErrorImage(with: "Error reading file: \(error.localizedDescription)")
            DispatchQueue.main.async {
                if let imageView = self.imageView {
                    imageView.image = errorImage
                }
            }
        }
    }

        private func decodeSnapshotData(_ data: Data) -> NSImage {
        let width = 256
        let height = 192

        // TODO is there a more minimal way that will be
        // TODO suitable for the Speccy screen's resolutions and colour needs?
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 3,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bitmapFormat: [],
            bytesPerRow: width * 3,
            bitsPerPixel: 24
        )!

        let displayStart = 27
        let displayLength = 32 * 192
        let attributeStart = displayStart + displayLength
        let attributeLength = 32 * 24
        
        let displayData = data[o: displayStart, l: displayLength]
        let attributeData = data[o: attributeStart, l: attributeLength]

        for chy in 0..<24 {
            for chx in 0..<32 {

                let at = attributeData[o: chy * 32 + chx]

                let ink = at & 0x07
                let ib = UInt8(bitPattern: -Int8(ink & 0b001))
                let ir = UInt8(bitPattern: -Int8(ink & 0b010)>>1)
                let ig = UInt8(bitPattern: -Int8(ink & 0b100)>>2)

                let paper = (at>>3) & 0x07
                let pb = UInt8(bitPattern: -Int8(paper & 0b001))
                let pr = UInt8(bitPattern: -Int8(paper & 0b010)>>1)
                let pg = UInt8(bitPattern: -Int8(paper & 0b100)>>2)

                let bright = (at & 0x40) != 0

                for pixY in 0..<8 {
                    let y = chy * 8 + pixY

                    let specY = (y & 0b11000000) | ((y & 0b00000111) << 3) | ((y & 0b00111000) >> 3)

                    let byte = displayData[o: specY * 32 + chx]
                    
                    let off = y * 256 * 3 + chx * 8 * 3;

                    for bit in 0..<8 {
                        var (r, g, b) = ((0b10000000 >> bit) & byte) != 0 ? (ir, ig, ib) : (pr, pg, pb)

                        if !bright { 
                            r = (r >> 2) + (r >> 1) + (r >> 3)
                            g = (g >> 2) + (g >> 1) + (g >> 3)
                            b = (b >> 2) + (b >> 1) + (b >> 3)
                        }

                        bitmap.bitmapData?.withMemoryRebound(to: UInt8.self, capacity: width * height * 3) { ptr in
                            ptr[off + bit * 3 + 0] = r
                            ptr[off + bit * 3 + 1] = g
                            ptr[off + bit * 3 + 2] = b
                        }
                    }
                }
            }
        }
        
        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }


    /// Create a simple error image with text
    private func createErrorImage(with message: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 256, height: 192))
        image.lockFocus()
        
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: 256, height: 192).fill()
        
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.red,
            .paragraphStyle: style
        ]
        
        let text = NSAttributedString(string: message, attributes: attributes)
        let rect = NSRect(x: 10, y: 80, width: 236, height: 32)
        text.draw(in: rect)
        
        image.unlockFocus()
        return image
    }
}
