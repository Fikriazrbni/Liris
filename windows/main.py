import json
import sys
from pathlib import Path

from PySide6.QtCore import QTimer
from PySide6.QtWidgets import QApplication

from liris.storage import Store
from liris.ui import MainWindow
from liris.branding import brand_icon, set_windows_app_id


def main():
    set_windows_app_id()
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    app.setApplicationName('Liris Windows')
    app.setWindowIcon(brand_icon())
    smoke = '--smoke-test' in sys.argv
    store = Store(Path(sys.argv[sys.argv.index('--smoke-test') + 1])) if smoke else Store()
    window = MainWindow(store)
    window.show()
    if smoke:
        # No device enumeration/capture/recognition or network calls. Exercise
        # the actual packaged UI and the privacy boundary, including reconnect.
        def verify():
            import numpy as np
            import pyaudiowpatch  # import only: do not instantiate PyAudio
            from liris.audio import pcm_wav
            wav = pcm_wav(np.zeros(48000 * 3, dtype=np.float32), 48000)
            assert wav[:4] == b'RIFF'
            window.connect_player()
            window.connect_player()
            assert not window.audio.enabled and window.audio.thread is None
            assert not app.windowIcon().isNull() and not window.windowIcon().isNull()
            window.overlay.show()
            window.overlay.set_locked(True)
            assert window.overlay.locked
            window.overlay.set_locked(False)
            window.grab().save(str(store.root / 'main.png'))
            window.overlay.grab().save(str(store.root / 'overlay.png'))
            (store.root / 'smoke.json').write_text(json.dumps({'ok': True, 'audio': 'off',
                'reconnectAudio': 'off', 'ui': 'rendered', 'overlayLock': 'toggled',
                'loopbackLibraryImported': True, 'syntheticResampling': True,
                'brandIconLoaded': True,
                'captureTested': False, 'recognitionTested': False}))
            window.quit()
        store.root.mkdir(parents=True, exist_ok=True)
        QTimer.singleShot(1200, verify)
    return app.exec()


if __name__ == '__main__':
    raise SystemExit(main())
