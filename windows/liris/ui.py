from __future__ import annotations

import concurrent.futures
import json
import os
import sys
import time
from pathlib import Path

from PySide6.QtCore import QObject, Qt, QTimer, Signal, QUrl
from PySide6.QtGui import QAction, QColor, QDesktopServices, QFont, QIcon, QPainter, QPixmap
from PySide6.QtWidgets import (QApplication, QCheckBox, QComboBox, QDoubleSpinBox, QFileDialog,
                               QHBoxLayout, QLabel, QLineEdit, QListWidget, QMainWindow, QMenu,
                               QMessageBox, QPushButton, QSlider, QStyle, QSystemTrayIcon,
                               QVBoxLayout, QWidget)

from liris.audio import AudioEngine
from liris.bridge import register
from liris.core import PlaybackClock, active_line, assess, parse_lrc, select_packet, signature
from liris.lyrics import LyricsClient
from liris.storage import Store, atomic_json, read_json


class Events(QObject):
    result = Signal(int, str, object)
    status = Signal(int, str)
    match = Signal(int, object, float)
    level = Signal(int, float)


class Overlay(QWidget):
    def __init__(self, owner):
        super().__init__()
        self.owner = owner
        self.setWindowTitle('Liris • Overlay')
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint)
        self.resize(650, 200)
        layout = QVBoxLayout(self)
        self.indicator = QLabel('Audio Mati')
        self.text = QLabel('Liris\nMenunggu lirik')
        self.text.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.text.setWordWrap(True)
        self.stop = QPushButton('Matikan audio')
        self.stop.clicked.connect(owner.stop_audio)
        layout.addWidget(self.indicator)
        layout.addWidget(self.text, 1)
        layout.addWidget(self.stop)
        self.locked = False
        self.apply_style()

    def apply_style(self):
        settings = self.owner.store.settings
        color = settings.get('color', '#c6f59b')
        size = settings.get('font_size', 30)
        self.setStyleSheet('QWidget { background: #161d21; color: #ecf0ee; } QPushButton { padding: 6px; }')
        self.text.setStyleSheet(f'color: {color}; font-size: {size}px; font-weight: 600;')
        self.setWindowOpacity(settings.get('opacity', 0.9))

    def set_locked(self, value):
        visible = self.isVisible()
        self.locked = value
        self.setWindowFlag(Qt.WindowType.WindowTransparentForInput, value)
        self.stop.setVisible(not value)
        if visible:
            self.show()
        self.owner.lock_overlay.setChecked(value)

    def closeEvent(self, event):
        self.hide()
        event.ignore()


class MainWindow(QMainWindow):
    def __init__(self, store=None):
        super().__init__()
        self.store = store or Store()
        self.client = LyricsClient(self.store)
        self.events = Events()
        self.pool = concurrent.futures.ThreadPoolExecutor(max_workers=2)
        self.generation = 0
        self.connected = False
        self.packet = None
        self.track = None
        self.track_key = None
        self.candidates = []
        self.lines = []
        self.current_line = -2
        self.clock = PlaybackClock()
        self.audio_deadline = 0
        self.audio_packet = None
        self.last_sound = 0
        self.audio_state = 'Mati'
        self.closing = False
        self.events.result.connect(self.got_result)
        self.events.status.connect(self.audio_status)
        self.events.match.connect(self.audio_match)
        self.events.level.connect(self.audio_level)
        self.audio = AudioEngine(self.events.status.emit, self.events.match.emit, self.events.level.emit)
        self.build_ui()
        self.overlay = Overlay(self)
        self.build_tray()
        self.poll = QTimer(self)
        self.poll.timeout.connect(self.tick)
        self.poll.start(100)
        self.setWindowTitle('Liris for Windows • Preview')
        self.resize(940, 780)

    def button(self, text, callback):
        button = QPushButton(text)
        button.clicked.connect(callback)
        return button

    def build_ui(self):
        self.setStyleSheet('''
            QMainWindow, QWidget { background: #11191d; color: #e8efea; font-family: Segoe UI; font-size: 14px; }
            QLabel#brand { color: #c6f59b; font-size: 32px; font-weight: 700; }
            QLabel#song { font-size: 24px; font-weight: 600; }
            QPushButton { background: #253238; border: 1px solid #394b50; border-radius: 7px; padding: 9px 14px; }
            QPushButton:hover { background: #35494c; }
            QPushButton:disabled { color: #71817c; }
            QPushButton#stop { background: #693c26; color: #fff0df; }
            QLineEdit, QListWidget, QComboBox, QDoubleSpinBox { background: #1a252a; border: 1px solid #35464c; border-radius: 6px; padding: 7px; }
            QListWidget::item { padding: 8px; }
            QListWidget::item:selected { background: #334d3e; color: #d3ffac; }
        ''')
        body = QWidget()
        self.setCentralWidget(body)
        layout = QVBoxLayout(body)
        layout.setContentsMargins(26, 20, 26, 20)
        layout.setSpacing(12)
        brand = QLabel('liris / windows')
        brand.setObjectName('brand')
        layout.addWidget(brand)
        layout.addWidget(QLabel('Lirik di ruang dengar Anda  ·  Windows preview'))
        connection = QHBoxLayout()
        self.connect_button = self.button('Hubungkan', self.connect_player)
        connection.addWidget(self.connect_button)
        connection.addWidget(self.button('Putuskan', self.disconnect_player))
        connection.addWidget(self.button('Setup extension', self.setup_extension))
        connection.addStretch()
        self.connection_status = QLabel('Belum terhubung')
        self.connection_status.setMinimumWidth(190)
        self.connection_status.setWordWrap(True)
        connection.addWidget(self.connection_status)
        layout.addLayout(connection)
        audio_row = QHBoxLayout()
        self.audio_indicator = QLabel('● Audio Mati')
        audio_row.addWidget(self.audio_indicator, 1)
        self.audio_enable = self.button('Aktifkan audio…', self.enable_audio)
        self.audio_enable.setEnabled(False)
        audio_row.addWidget(self.audio_enable)
        self.audio_stop = self.button('Matikan audio', self.stop_audio)
        self.audio_stop.setObjectName('stop')
        audio_row.addWidget(self.audio_stop)
        layout.addLayout(audio_row)
        privacy = QLabel('Output sistem saja • Percakapan yang diputar bisa ikut dianalisis. Audio selalu mati pada koneksi baru.')
        privacy.setWordWrap(True)
        layout.addWidget(privacy)
        self.song = QLabel('Menunggu pemutar')
        self.song.setObjectName('song')
        self.song.setWordWrap(True)
        layout.addWidget(self.song)
        self.source = QLabel('YouTube / YouTube Music melalui extension. Audio sistem bersifat opsional.')
        self.source.setWordWrap(True)
        layout.addWidget(self.source)
        self.sync_status = QLabel('Belum ada lirik')
        self.sync_status.setWordWrap(True)
        layout.addWidget(self.sync_status)
        self.lyrics_list = QListWidget()
        self.lyrics_list.itemDoubleClicked.connect(self.seek_line)
        layout.addWidget(self.lyrics_list, 1)
        controls = QHBoxLayout()
        self.play = self.button('Play / pause', lambda: self.command('toggle'))
        controls.addWidget(self.play)
        self.position = QLabel('0:00')
        controls.addWidget(self.position)
        controls.addStretch()
        controls.addWidget(QLabel('Offset lirik (detik)'))
        self.offset = QDoubleSpinBox()
        self.offset.setRange(-10, 10)
        self.offset.setSingleStep(0.2)
        self.offset.setDecimals(1)
        self.offset.valueChanged.connect(self.offset_changed)
        controls.addWidget(self.offset)
        controls.addWidget(self.button('Overlay', self.toggle_overlay))
        layout.addLayout(controls)
        search = QHBoxLayout()
        self.query = QLineEdit()
        self.query.setPlaceholderText('Cari judul dan artis di LRCLIB')
        self.query.returnPressed.connect(self.search)
        search.addWidget(self.query, 1)
        search.addWidget(self.button('Cari', self.search))
        search.addWidget(self.button('Impor LRC', self.import_lrc))
        search.addWidget(self.button('Periksa ulang', self.refresh))
        layout.addLayout(search)
        versions = QHBoxLayout()
        self.versions = QComboBox()
        self.versions.setMinimumWidth(320)
        versions.addWidget(self.versions, 1)
        versions.addWidget(self.button('Pakai versi', self.choose_version))
        versions.addWidget(self.button('Pilihan otomatis', self.reset_choice))
        layout.addLayout(versions)
        display = QHBoxLayout()
        self.lock_overlay = QCheckBox('Klik menembus (buka lewat tray)')
        self.lock_overlay.toggled.connect(lambda v: self.overlay.set_locked(v))
        display.addWidget(self.lock_overlay)
        colors = QComboBox()
        for name, color in [('Lime', '#c6f59b'), ('Lavender', '#d6c6ff'), ('Peach', '#ffcca6')]:
            colors.addItem(name, color)
        colors.setCurrentIndex(max(0, colors.findData(self.store.settings.get('color', '#c6f59b'))))
        colors.currentIndexChanged.connect(lambda _: self.display_setting('color', colors.currentData()))
        display.addWidget(colors)
        display.addWidget(QLabel('Ukuran'))
        size = QSlider(Qt.Orientation.Horizontal)
        size.setRange(18, 64)
        size.setValue(self.store.settings.get('font_size', 30))
        size.valueChanged.connect(lambda v: self.display_setting('font_size', v))
        display.addWidget(size)
        display.addWidget(QLabel('Opasitas'))
        opacity = QSlider(Qt.Orientation.Horizontal)
        opacity.setRange(25, 100)
        opacity.setValue(int(self.store.settings.get('opacity', 0.9) * 100))
        opacity.valueChanged.connect(lambda v: self.display_setting('opacity', v / 100))
        display.addWidget(opacity)
        layout.addLayout(display)

    def build_tray(self):
        self.tray = QSystemTrayIcon(self)
        self.tray.setToolTip('Liris • Audio Mati')
        self.tray.setIcon(self.tray_icon(False))
        menu = QMenu()
        for title, callback in [('Buka Liris', self.showNormal), ('Overlay tampil/sembunyi', self.toggle_overlay),
                                ('Buka kunci overlay', lambda: self.overlay.set_locked(False)),
                                ('Matikan audio', self.stop_audio), ('Keluar', self.quit)]:
            action = menu.addAction(title)
            action.triggered.connect(callback)
        self.tray.setContextMenu(menu)
        self.tray.activated.connect(lambda reason: self.showNormal() if reason == QSystemTrayIcon.ActivationReason.DoubleClick else None)
        self.tray.show()

    def tray_icon(self, active):
        pixmap = QPixmap(32, 32)
        pixmap.fill(Qt.GlobalColor.transparent)
        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setBrush(QColor('#ffb067' if active else '#c6f59b'))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(3, 3, 26, 26)
        painter.setPen(QColor('#11191d'))
        painter.setFont(QFont('Segoe UI', 18, QFont.Weight.Bold))
        painter.drawText(pixmap.rect(), Qt.AlignmentFlag.AlignCenter, 'L')
        painter.end()
        return QIcon(pixmap)

    def connect_player(self):
        self.stop_audio()
        self.clear_track()
        self.connected = True
        self.connection_status.setText('Menunggu extension')
        self.audio_enable.setEnabled(not (self.audio.thread and self.audio.thread.is_alive()))

    def disconnect_player(self):
        self.connected = False
        self.stop_audio()
        self.clear_track()
        self.connection_status.setText('Terputus')
        self.audio_enable.setEnabled(False)

    def clear_track(self):
        self.generation += 1
        self.packet = self.track = self.track_key = self.audio_packet = None
        self.audio_deadline = 0
        self.clock = PlaybackClock()
        self.candidates = []
        self.versions.clear()
        self.set_lyrics(None)
        self.song.setText('Menunggu pemutar')

    def setup_extension(self):
        try:
            if not getattr(sys, 'frozen', False):
                raise ValueError('Setup memakai LirisBridge.exe dari paket. Bangun paket terlebih dahulu; lihat windows/README.md.')
            folder = Path(sys._MEIPASS) / 'Extension'
            register(Path(sys.executable).parent / 'LirisBridge.exe', folder)
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(folder)))
            QMessageBox.information(self, 'Extension', 'Host terdaftar untuk Chrome, Brave, dan Edge pada akun Windows ini.\n'
                                    'Buka halaman Extensions browser → Developer mode → Load unpacked → pilih folder Extension yang dibuka.\n'
                                    'Reload tab YouTube lalu Hubungkan. Jika paket dipindah, jalankan setup lagi.')
        except (OSError, ValueError) as error:
            QMessageBox.warning(self, 'Setup extension', str(error))

    def enable_audio(self):
        if not self.connected:
            return
        answer = QMessageBox.question(self, 'Aktifkan pengenalan output sistem?',
                                      'Cuplikan 12 detik hanya di RAM. Signature dikirim ke layanan Shazam melalui ShazamIO.\n'
                                      'Output percakapan Discord/aplikasi lain dapat ikut dianalisis. Mikrofon tidak dibuka.\n'
                                      'Aktifkan untuk koneksi ini?', QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                                      QMessageBox.StandardButton.No)
        if answer == QMessageBox.StandardButton.Yes:
            self.audio.start_manual()

    def stop_audio(self):
        self.audio.stop()
        self.audio_packet = None
        self.audio_deadline = 0
        if self.track and self.track.get('origin') == 'audio':
            self.clear_track()

    def audio_status(self, epoch, status):
        if epoch != self.audio.epoch:
            return
        self.audio_state = status
        active = self.audio.enabled or status.startswith('Menghentikan')
        label = '● Audio ' + status
        self.audio_indicator.setText(label)
        self.audio_indicator.setStyleSheet('color: ' + ('#ffb067' if active else '#a1b1a8'))
        self.overlay.indicator.setText(label)
        self.overlay.indicator.setStyleSheet(self.audio_indicator.styleSheet())
        self.audio_enable.setEnabled(self.connected and not active)
        self.tray.setToolTip('Liris • Audio ' + status)
        self.tray.setIcon(self.tray_icon(active))

    def audio_match(self, epoch, result, started):
        if epoch != self.audio.epoch or not self.audio.enabled or not self.connected or self.packet:
            return
        now = time.monotonic()
        p = {'session': 'audio', 'trackID': result['title'] + '|' + result['artist'], 'title': result['title'],
             'artist': result['artist'], 'album': '', 'duration': 0, 'origin': 'audio',
             'playing': True, 'position': result['offset'] + now - started, 'receivedAt': time.time()}
        self.audio_packet = p
        self.audio_deadline = now + 35
        self.use_track(p)
        self.clock.update(p, now)

    def audio_level(self, epoch, level):
        if epoch != self.audio.epoch or not self.audio.enabled:
            return
        now = time.monotonic()
        if level >= 0.001:
            self.last_sound = now
        if self.audio_packet and not self.packet:
            # Sound presence does not prove playback continuity or a seek. Hold
            # on silence; only a fresh recognition establishes a new position.
            position = self.clock.value(now)
            playing = now - self.last_sound < 1
            self.audio_packet.update(position=position, playing=playing, receivedAt=time.time())
            self.clock.update(self.audio_packet, now)

    def tick(self):
        if self.connected:
            packets = [read_json(path, {}) for path in (self.store.root / 'Bridge').glob('*.json')]
            p = select_packet(packets, self.packet['session'] if self.packet else None)
            self.packet = p
            self.audio.suppress(bool(p and p['playing']))
            if p:
                if p['advertisement']:
                    self.audio.suppress(True)
                    if self.track:
                        self.clear_track()
                    self.packet = p
                    self.connection_status.setText('Iklan • lirik ditahan')
                    self.play.setEnabled(False)
                    return
                if p['playing']:
                    self.audio_deadline = 0
                    self.audio_packet = None
                self.connection_status.setText('Extension terhubung')
                self.use_track(p)
                self.clock.update(p)
                self.source.setText(p['origin'] + ' • waktu pemutar • status pause/seek mengikuti heartbeat')
            elif self.audio_packet and time.monotonic() < self.audio_deadline:
                self.connection_status.setText('Pengenalan audio')
                self.use_track(self.audio_packet)
                self.source.setText('ShazamIO • posisi perkiraan; pause/seek/pergantian lagu belum terverifikasi sampai pengenalan berikutnya')
            else:
                self.connection_status.setText('Menunggu extension / audio')
                if self.track:
                    self.clear_track()
        position = self.clock.value()
        self.position.setText(f'{int(position)//60}:{int(position)%60:02d}')
        index = active_line(self.lines, position + self.offset.value())
        if index != self.current_line:
            self.current_line = index
            self.lyrics_list.setCurrentRow(index)
            if index >= 0:
                self.lyrics_list.scrollToItem(self.lyrics_list.item(index))
            self.overlay.text.setText(self.lines[index].text if index >= 0 else ('Menunggu lirik' if not self.lines else '♪'))
        self.play.setEnabled(bool(self.packet))

    def use_track(self, packet):
        key = signature(packet)
        if key == self.track_key:
            self.track = packet.copy()
            return
        self.generation += 1
        self.track_key = key
        self.track = packet.copy()
        self.song.setText(packet['title'] + '  /  ' + packet['artist'])
        local = self.store.track(key)
        self.offset.blockSignals(True)
        self.offset.setValue(local.get('offset', 0))
        self.offset.blockSignals(False)
        self.set_lyrics(None)
        self.candidates = []
        self.versions.clear()
        self.sync_status.setText('Mencari lirik…')
        self.submit('resolve', lambda track=packet.copy(): self.client.resolve(track))

    def submit(self, kind, operation):
        generation = self.generation
        def job():
            try:
                result = operation()
            except Exception as error:
                result = error
            if not self.closing:
                self.events.result.emit(generation, kind, result)
        self.pool.submit(job)

    def got_result(self, generation, kind, result):
        if generation != self.generation:
            return
        if isinstance(result, Exception):
            self.sync_status.setText('Gagal: ' + str(result))
            return
        if kind == 'resolve':
            chosen, candidates, status = result
            self.candidates = candidates
            self.populate_versions()
            self.set_lyrics(chosen)
            self.sync_status.setText(status)
        else:
            self.candidates = result
            self.populate_versions()
            self.sync_status.setText(f'{len(result)} versi ditemukan. Pilih versi untuk melihat lirik.')

    def populate_versions(self):
        self.versions.clear()
        for c in self.candidates:
            reasons = assess(c, self.track) if self.track else ['belum ada pemutar']
            text = f"{c.get('trackName')} — {c.get('artistName')} / {c.get('albumName', '')} / {c.get('duration', '?')}s"
            if reasons:
                text += ' ⚠ ' + ', '.join(reasons)
            self.versions.addItem(text, c)

    def set_lyrics(self, candidate):
        self.lyrics_list.clear()
        self.lines = parse_lrc((candidate or {}).get('syncedLyrics') or '')
        self.current_line = -2
        if self.lines:
            self.lyrics_list.addItems([line.text or '♪' for line in self.lines])
        else:
            text = (candidate or {}).get('plainLyrics') or 'Lirik akan muncul di sini.'
            self.lyrics_list.addItems(text.splitlines())

    def search(self):
        query = self.query.text().strip()
        if not query:
            return
        self.generation += 1
        self.sync_status.setText('Mencari di LRCLIB…')
        self.submit('search', lambda: self.client.search(query))

    def choose_version(self):
        c = self.versions.currentData()
        if not c:
            return
        self.generation += 1
        self.set_lyrics(c)
        reasons = assess(c, self.track) if self.track else ['pemutar belum terhubung']
        self.sync_status.setText('Pilihan manual • ' + (', '.join(reasons) if reasons else 'metadata/durasi cocok; kecocokan vokal belum terbukti'))
        if self.track_key and not reasons:
            local = self.store.track(self.track_key)
            candidates = local.get('candidates', [])
            candidates = [x for x in candidates if x.get('id') != c.get('id')]
            self.store.update_track(self.track_key, {'choice': c.get('id'), 'candidates': [c] + candidates[:31]})

    def refresh(self):
        if self.track:
            self.generation += 1
            self.submit('resolve', lambda track=self.track.copy(): self.client.resolve(track, force=True))

    def reset_choice(self):
        if self.track_key:
            self.store.update_track(self.track_key, {}, remove=('choice', 'offset'))
            self.offset.setValue(0)
            self.refresh()

    def offset_changed(self, value):
        if self.track_key:
            self.store.update_track(self.track_key, {'offset': value})

    def import_lrc(self):
        name, _ = QFileDialog.getOpenFileName(self, 'Impor LRC UTF-8', '', 'Lyrics (*.lrc *.txt)')
        if not name:
            return
        try:
            if Path(name).stat().st_size > 4_000_000:
                raise ValueError('File terlalu besar')
            text = Path(name).read_text(encoding='utf-8-sig')
            self.generation += 1
            self.set_lyrics({'syncedLyrics': text, 'plainLyrics': text})
            self.sync_status.setText('Impor manual • versi/durasi belum diverifikasi; tanpa timestamp tidak dibuat timing buatan')
        except (OSError, ValueError) as error:
            QMessageBox.warning(self, 'Impor gagal', str(error))

    def command(self, command, target=0):
        if self.packet:
            if command == 'seek' and self.packet.get('quantized'):
                self.sync_status.setText('Seek melalui Liris dinonaktifkan saat waktu media tidak sejalan; gunakan pemutar.')
                return
            packet = dict(self.packet, command=command, target=target, receivedAt=time.time())
            atomic_json(self.store.root / 'Bridge' / (packet['session'] + '.command'), packet)

    def seek_line(self, item):
        row = self.lyrics_list.row(item)
        if 0 <= row < len(self.lines):
            self.command('seek', max(0, self.lines[row].time - self.offset.value()))

    def display_setting(self, name, value):
        self.store.settings[name] = value
        self.store.save()
        self.overlay.apply_style()

    def toggle_overlay(self):
        self.overlay.setVisible(not self.overlay.isVisible())

    def closeEvent(self, event):
        if QSystemTrayIcon.isSystemTrayAvailable() and not self.closing:
            self.hide()
            event.ignore()
        else:
            self.quit()
            event.accept()

    def quit(self):
        if self.closing:
            return
        self.closing = True
        self.poll.stop()
        self.stop_audio()
        self.audio.wait()
        self.pool.shutdown(wait=False, cancel_futures=True)
        self.overlay.hide()
        self.tray.hide()
        QApplication.instance().quit()
