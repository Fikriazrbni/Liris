"""Windows rendition of scripts/generate-icon.swift's existing Liris mark."""
import ctypes
import sys
from PySide6.QtCore import QRectF, Qt
from PySide6.QtGui import QImage, QPainter, QColor, QPixmap, QIcon

SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)
APP_ID = 'id.local.liris.Windows'


def brand_image(size, active=False):
    image = QImage(size, size, QImage.Format.Format_ARGB32_Premultiplied)
    image.fill(Qt.GlobalColor.transparent)
    p = QPainter(image)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    p.scale(size / 1024, size / 1024)
    p.setPen(Qt.PenStyle.NoPen)
    p.setBrush(QColor('#C9F07A'))
    p.drawRoundedRect(QRectF(32, 32, 960, 960), 218, 218)
    p.setBrush(QColor('#0E1011'))
    for i, height in enumerate((120, 245, 390, 520, 350, 220, 110)):
        p.drawRoundedRect(QRectF(247 + i * 78, 512 - height / 2, 42, height), 21, 21)
    if active:
        # Keep the brand recognizable while retaining the existing audio indicator.
        p.setBrush(QColor('#0E1011'))
        p.drawEllipse(QRectF(676, 676, 340, 340))
        p.setBrush(QColor('#FFB05C'))
        p.drawEllipse(QRectF(720, 720, 252, 252))
    p.end()
    return image


def brand_icon(active=False):
    icon = QIcon()
    for size in SIZES:
        icon.addPixmap(QPixmap.fromImage(brand_image(size, active)))
    return icon


def set_windows_app_id():
    if sys.platform == 'win32':
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APP_ID)
