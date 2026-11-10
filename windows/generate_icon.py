"""Generate a multi-resolution Windows ICO from Liris' existing vector mark."""
import struct
from pathlib import Path
from PySide6.QtCore import QBuffer, QIODevice
from liris.branding import SIZES, brand_image


def main():
    folder = Path(__file__).resolve().parent / 'assets'
    folder.mkdir(exist_ok=True)
    frames = []
    for size in SIZES:
        buffer = QBuffer()
        buffer.open(QIODevice.OpenModeFlag.WriteOnly)
        assert brand_image(size).save(buffer, 'PNG')
        frames.append((size, bytes(buffer.data())))
    header = bytearray(struct.pack('<HHH', 0, 1, len(frames)))
    offset = 6 + 16 * len(frames)
    for size, data in frames:
        header.extend(struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(data), offset))
        offset += len(data)
    (folder / 'liris.ico').write_bytes(header + b''.join(data for _, data in frames))
    assert brand_image(512).save(str(folder / 'liris.png'))
    print('Generated Liris ICO (16–256 px) and 512 px preview')


if __name__ == '__main__':
    main()
