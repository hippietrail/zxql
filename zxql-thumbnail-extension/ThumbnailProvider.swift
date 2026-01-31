//
//  ThumbnailProvider.swift
//  zxql-thumbnail-extension
//
//  Created by Andrew Dunbar on 31/1/2026.
//

import Cocoa
import QuickLookThumbnailing

extension RandomAccessCollection {
    subscript(o offset: Int) -> Element {
        return self[index(startIndex, offsetBy: offset)]
    }
    subscript(o offset: Int, l length: Int) -> SubSequence {
        let startIndex = self.index(self.startIndex, offsetBy: offset)
        let endIndex = self.index(startIndex, offsetBy: length)
        return self[startIndex..<endIndex]
    }
}

class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        do {
            let data = try Data(contentsOf: request.fileURL)
            guard data.count == 49179 else {
                throw NSError(domain: "ThumbnailProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid .sna file size"])
            }
            
            let width = 256
            let height = 192
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
            
            guard let bitmapPtr = bitmap.bitmapData else {
                throw NSError(domain: "ThumbnailProvider", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap"])
            }
            
            for charY in 0..<24 {
                for charX in 0..<32 {
                    let attr = attributeData[o: charY * 32 + charX]
                    
                    let ink = attr & 0x07
                    let inkB = UInt8(bitPattern: -Int8(ink & 0b001))
                    let inkR = UInt8(bitPattern: -Int8(ink & 0b010)>>1)
                    let inkG = UInt8(bitPattern: -Int8(ink & 0b100)>>2)
                    
                    let paper = (attr>>3) & 0x07
                    let paperB = UInt8(bitPattern: -Int8(paper & 0b001))
                    let paperR = UInt8(bitPattern: -Int8(paper & 0b010)>>1)
                    let paperG = UInt8(bitPattern: -Int8(paper & 0b100)>>2)
                    
                    let bright = (attr & 0x40) != 0
                    
                    for pixY in 0..<8 {
                        let y = charY * 8 + pixY
                        let specY = (y & 0b11000000) | ((y & 0b00000111) << 3) | ((y & 0b00111000) >> 3)
                        let byte = displayData[o: specY * 32 + charX]
                        let off = y * 256 * 3 + charX * 8 * 3
                        
                        for bit in 0..<8 {
                            var (r, g, b) = ((0b10000000 >> bit) & byte) != 0 ? (inkR, inkG, inkB) : (paperR, paperG, paperB)
                            
                            if !bright {
                                r = (r >> 2) + (r >> 1) + (r >> 3)
                                g = (g >> 2) + (g >> 1) + (g >> 3)
                                b = (b >> 2) + (b >> 1) + (b >> 3)
                            }
                            
                            let pixelOffset = off + bit * 3
                            bitmapPtr[pixelOffset] = r
                            bitmapPtr[pixelOffset + 1] = g
                            bitmapPtr[pixelOffset + 2] = b
                        }
                    }
                }
            }
            
            let image = NSImage(size: bitmap.size)
            image.addRepresentation(bitmap)
            
            let reply = QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in
                image.draw(in: NSRect(origin: .zero, size: request.maximumSize))
                return true
            })
            
            handler(reply, nil)
        } catch {
            handler(nil, error)
        }
    }
}
