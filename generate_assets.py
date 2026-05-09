"""Generate IAPTest/Assets.xcassets with AppIcon.appiconset (1024x1024)."""
import os
import json
import struct
import zlib


def _png_chunk(typ, data):
    crc = zlib.crc32(typ + data) & 0xFFFFFFFF
    return struct.pack('>I', len(data)) + typ + data + struct.pack('>I', crc)


def make_solid_png(width, height, color):
    """Create a minimal solid-color PNG. color: (r,g,b)."""
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    raw = b''
    rgb = bytes(color) * width
    for _ in range(height):
        raw += b'\x00' + rgb
    idat = zlib.compress(raw, 9)
    return sig + _png_chunk(b'IHDR', ihdr) + _png_chunk(b'IDAT', idat) + _png_chunk(b'IEND', b'')


def main():
    base = 'IAPTest/Assets.xcassets'
    appicon = f'{base}/AppIcon.appiconset'
    os.makedirs(appicon, exist_ok=True)

    # Top-level Assets.xcassets/Contents.json
    with open(f'{base}/Contents.json', 'w') as f:
        json.dump({
            "info": {"author": "xcode", "version": 1}
        }, f, indent=2)

    # AppIcon.appiconset/Contents.json — modern single-size 1024 universal
    with open(f'{appicon}/Contents.json', 'w') as f:
        json.dump({
            "images": [
                {
                    "filename": "icon-1024.png",
                    "idiom": "universal",
                    "platform": "ios",
                    "size": "1024x1024"
                }
            ],
            "info": {"author": "xcode", "version": 1}
        }, f, indent=2)

    # Generate the 1024x1024 PNG
    png = make_solid_png(1024, 1024, (32, 80, 220))  # blue
    with open(f'{appicon}/icon-1024.png', 'wb') as f:
        f.write(png)

    print(f'Generated {appicon}/icon-1024.png ({len(png)} bytes)')
    print(f'Generated {appicon}/Contents.json')
    print(f'Generated {base}/Contents.json')


if __name__ == '__main__':
    main()
