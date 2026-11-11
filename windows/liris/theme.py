"""Shared Windows presentation tokens. No player or audio state lives here."""
TOKENS = dict(background='#0E1011', sidebar='#131516', card='#1A1D1D',
              lime='#C9F07A', lavender='#BAA6FF', peach='#FFB887',
              muted='#8C9691', text='#E8ECE9', border='#2B2F2D', orange='#FFB05C')

STYLE = '''
QWidget { background: #0E1011; color: #E8ECE9; font-family: "Segoe UI"; font-size: 13px; }
QLabel { background: transparent; }
QWidget#sidebar { background: #131516; border-right: 1px solid #252927; }
QWidget#card, QWidget#settings { background: #1A1D1D; border: 1px solid #2B2F2D; border-radius: 15px; }
QWidget#card QLabel, QWidget#settings QLabel { background: transparent; border: none; }
QWidget#banner { background: #131516; border: 1px solid #303532; border-radius: 13px; }
QWidget#banner[active="true"] { background: #2A2017; border-color: #654323; }
QWidget#banner QLabel { background: transparent; border: none; }
QLabel#eyebrow { color: #8C9691; font-size: 10px; font-weight: 600; letter-spacing: 2px; }
QLabel#heading { font-size: 24px; font-weight: 600; }
QLabel#song { font-size: 25px; font-weight: 600; }
QLabel#muted { color: #8C9691; }
QPushButton { background: #1C1F1E; border: 1px solid #303532; border-radius: 9px; padding: 8px 12px; font-weight: 600; }
QPushButton:hover { background: #292F28; border-color: #657254; }
QPushButton:pressed { background: #35402B; }
QPushButton:focus, QComboBox:focus, QLineEdit:focus, QDoubleSpinBox:focus, QCheckBox:focus { border: 2px solid #C9F07A; }
QPushButton:disabled { color: #717A74; background: #171A18; border-color: #252927; }
QPushButton#primary, QPushButton#play { background: #C9F07A; color: #182011; border: none; }
QPushButton#primary:hover, QPushButton#play:hover { background: #DAFF96; }
QPushButton#primary:disabled, QPushButton#play:disabled { background: #424D34; color: #929C87; }
QPushButton#play { border-radius: 23px; font-size: 20px; }
QPushButton#nav { text-align: left; padding: 13px 12px; border: 1px solid transparent; background: transparent; color: #A8B0AB; }
QPushButton#nav:checked { background: #252D1B; color: #C9F07A; }
QPushButton#nav:focus { border-color: #C9F07A; }
QPushButton#stop { color: #FFB05C; background: #38291C; border-color: #6A482A; }
QLineEdit, QComboBox, QDoubleSpinBox { background: #131616; border: 1px solid #303532; border-radius: 8px; padding: 8px; selection-background-color: #455932; }
QComboBox::drop-down { border: none; width: 22px; }
QComboBox QAbstractItemView { background: #1A1D1D; selection-background-color: #354329; }
QListWidget { border: none; background: transparent; outline: none; }
QListWidget::item { background: transparent; border: none; padding: 10px 6px; color: #A5AEA7; }
QListWidget::item:selected { background: transparent; color: #C9F07A; }
QListWidget:focus { border: 1px solid #657254; border-radius: 8px; }
QScrollArea { border: none; background: transparent; }
QScrollBar:vertical { background: transparent; width: 7px; margin: 2px; }
QScrollBar::handle:vertical { background: #414942; border-radius: 3px; min-height: 24px; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QSlider::groove:horizontal { height: 3px; background: #353B36; border-radius: 1px; }
QSlider::handle:horizontal { background: #E8ECE9; width: 13px; margin: -5px 0; border-radius: 6px; }
QSlider { background: transparent; min-height: 20px; }
QSlider::sub-page:horizontal, QSlider::add-page:horizontal { background: #353B36; border: none; height: 3px; }
QSlider:focus::handle:horizontal { background: #C9F07A; }
QCheckBox { spacing: 8px; background: transparent; }
QCheckBox::indicator { width: 16px; height: 16px; border: 1px solid #8C9691; border-radius: 4px; }
QCheckBox::indicator:checked { background: #C9F07A; border-color: #C9F07A; }
QMenu, QMessageBox { background: #1A1D1D; }
QMenu::item { padding: 8px 20px; }
QMenu::item:selected { background: #354329; }
'''


def high_contrast():
    import ctypes
    import sys
    if sys.platform != 'win32':
        return False
    class HIGHCONTRAST(ctypes.Structure):
        _fields_ = [('size', ctypes.c_uint), ('flags', ctypes.c_uint), ('scheme', ctypes.c_void_p)]
    value = HIGHCONTRAST()
    value.size = ctypes.sizeof(value)
    return bool(ctypes.windll.user32.SystemParametersInfoW(0x42, value.size, ctypes.byref(value), 0) and value.flags & 1)
