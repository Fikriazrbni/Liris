"""Qt Widgets composition. Existing MainWindow callbacks own all production state."""
from PySide6.QtCore import Qt, QTimer, QSize, QPointF, QPropertyAnimation, QEasingCurve
from PySide6.QtGui import QColor, QFont, QPainter, QPixmap
from PySide6.QtWidgets import (QWidget, QLabel, QVBoxLayout, QHBoxLayout, QPushButton,
    QScrollArea, QStackedWidget, QComboBox, QSlider, QDoubleSpinBox, QCheckBox,
    QListWidget, QLineEdit, QSizePolicy, QStyledItemDelegate, QStyle, QAbstractItemView)
from liris.theme import STYLE, TOKENS, high_contrast


def label(text, role='', wrap=True):
    w = QLabel(text)
    w.setObjectName(role)
    w.setWordWrap(wrap)
    w.setTextFormat(Qt.TextFormat.PlainText)
    w.setMinimumWidth(0)
    w.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Preferred)
    return w


def box(role='', margin=18, gap=12):
    w = QWidget()
    w.setObjectName(role)
    layout = QVBoxLayout(w)
    layout.setContentsMargins(margin, margin, margin, margin)
    layout.setSpacing(gap)
    return w, layout


def scroll(widget):
    area = QScrollArea()
    area.setWidgetResizable(True)
    area.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
    area.setWidget(widget)
    return area


def artwork(size=106):
    p = QPixmap(size, size)
    p.fill(QColor('#202C22'))
    painter = QPainter(p)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    for r in range(12, size, 7):
        painter.setPen(QColor('#61763D'))
        painter.drawEllipse(size//2-r, size//2-r, 2*r, 2*r)
    painter.setBrush(QColor(TOKENS['lime']))
    painter.drawEllipse(size//2-7, size//2-7, 14, 14)
    painter.end()
    return p


class LyricDelegate(QStyledItemDelegate):
    def paint(self, painter, option, index):
        self.initStyleOption(option, index)
        painter.save()
        painter.setFont(option.font)
        painter.setPen(QColor(TOKENS['lime'] if option.state & QStyle.StateFlag.State_Selected else '#A5AEA7'))
        painter.drawText(option.rect.adjusted(10, 8, -10, -8), Qt.AlignmentFlag.AlignCenter | Qt.TextFlag.TextWordWrap, index.data() or '')
        painter.restore()

    def initStyleOption(self, option, index):
        super().initStyleOption(option, index)
        active = bool(option.state & QStyle.StateFlag.State_Selected)
        option.font.setPixelSize(29 if active else 21)
        option.font.setWeight(QFont.Weight.DemiBold if active else QFont.Weight.Normal)
        option.displayAlignment = Qt.AlignmentFlag.AlignCenter
        option.features |= option.ViewItemFeature.WrapText

    def sizeHint(self, option, index):
        self.initStyleOption(option, index)
        from PySide6.QtGui import QFontMetrics
        option.font.setPixelSize(29)
        fm = QFontMetrics(option.font)
        rect = fm.boundingRect(0, 0, max(100, self.parent().viewport().width()-24), 1000,
                               Qt.TextFlag.TextWordWrap, index.data() or '')
        return QSize(100, max(62, rect.height()+24))


class ThinSlider(QSlider):
    """Native QSlider input/keyboard semantics with a quiet, DPI-aware track."""
    def paintEvent(self, event):
        if high_contrast():
            return super().paintEvent(event)
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        y = self.height()/2
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(QColor('#353B36'))
        p.drawRoundedRect(7, int(y-1), self.width()-14, 3, 1, 1)
        fraction = (self.value()-self.minimum()) / max(1, self.maximum()-self.minimum())
        x = 7 + fraction * (self.width()-14)
        p.setBrush(QColor('#E8ECE9' if self.isEnabled() else '#6A756D'))
        p.drawEllipse(QPointF(x, y), 6, 6)
        if self.hasFocus():
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.setPen(QColor(TOKENS['lime']))
            p.drawEllipse(QPointF(x, y), 9, 9)
        p.end()


def build_main(w):
    w.setStyleSheet('' if high_contrast() else STYLE)
    w.setMinimumSize(940, 640)
    root = QWidget()
    w.setCentralWidget(root)
    outer = QHBoxLayout(root)
    outer.setContentsMargins(0, 0, 0, 0)
    outer.setSpacing(0)
    sidebar, nav = box('sidebar', 20, 12)
    sidebar.setFixedWidth(205)
    brand_row = QHBoxLayout()
    from liris.branding import brand_icon
    icon = QLabel()
    icon.setPixmap(brand_icon().pixmap(36, 36))
    icon.setFixedSize(36, 36)
    brand_row.addWidget(icon)
    brand = label('liris', 'heading')
    brand.setStyleSheet('font-size: 32px; font-weight: 600;')
    brand_row.addWidget(brand, 1)
    nav.addLayout(brand_row)
    nav.addWidget(label('A LITTLE CLOSER TO THE MUSIC', 'eyebrow'))
    nav.addSpacing(32)
    nav.addWidget(label('RUANG DENGAR', 'eyebrow'))
    w.nav_buttons = []
    for title in ('♪   Sedang diputar', '⌕   Cari lirik', '☷   Tampilan'):
        b = w.button(title, lambda checked=False, i=len(w.nav_buttons): show_page(w, i))
        b.setObjectName('nav')
        b.setCheckable(True)
        nav.addWidget(b)
        w.nav_buttons.append(b)
    nav.addStretch()
    nav.addWidget(label('“\nAda cerita\ndi setiap nada.', 'heading'))
    nav.addWidget(label('Beri ruang untuk mendengarnya.', 'muted'))
    nav.addSpacing(24)
    guide = w.button('ⓘ   Panduan koneksi', lambda: show_page(w, 3))
    guide.setObjectName('nav')
    guide.setCheckable(True)
    w.nav_buttons.append(guide)
    nav.addWidget(guide)
    nav.addWidget(label('LIRIS  /  WINDOWS PREVIEW', 'eyebrow'))
    outer.addWidget(sidebar)
    content, content_layout = box('', 26, 16)
    outer.addWidget(content, 1)
    header = QHBoxLayout()
    title_col = QVBoxLayout()
    title_col.addWidget(label('YOUR EVERYDAY SOUNDTRACK', 'eyebrow'))
    w.page_heading = label('Musikmu, kata demi kata.', 'heading')
    title_col.addWidget(w.page_heading)
    header.addLayout(title_col, 1)
    w.demo_badge = QLabel('DEMO VISUAL · TANPA AUDIO')
    w.demo_badge.setStyleSheet('color: #C9F07A; font-size: 10px;')
    w.demo_badge.hide()
    header.addWidget(w.demo_badge)
    header.addWidget(w.button('▣  Buka overlay', w.toggle_overlay))
    content_layout.addLayout(header)
    w.audio_banner, banner = box('banner', 16, 4)
    audio_row = QHBoxLayout()
    audio_text = QVBoxLayout()
    w.audio_indicator = label('● Audio Mati')
    w.audio_indicator.setStyleSheet('font-weight: 600;')
    w.audio_detail = label('Aktifkan manual setelah terhubung. Connect/reconnect tidak menyalakan audio.', 'muted')
    audio_text.addWidget(w.audio_indicator)
    audio_text.addWidget(w.audio_detail)
    audio_row.addLayout(audio_text, 1)
    w.audio_enable = w.button('Aktifkan audio…', w.enable_audio)
    w.audio_enable.setEnabled(False)
    w.audio_stop = w.button('Matikan audio', w.stop_audio)
    w.audio_stop.setObjectName('stop')
    audio_row.addWidget(w.audio_enable)
    audio_row.addWidget(w.audio_stop)
    banner.addLayout(audio_row)
    content_layout.addWidget(w.audio_banner)
    columns = QHBoxLayout()
    columns.setSpacing(24)
    w.pages = QStackedWidget()
    columns.addWidget(w.pages, 1)
    content_layout.addLayout(columns, 1)
    main, fixed_main = box('', 0, 8)
    w.pages.addWidget(main)
    stage, main_layout = box('', 0, 12)
    stage.setMinimumHeight(470)
    w.stage_scroll = scroll(stage)
    fixed_main.addWidget(w.stage_scroll, 1)
    connection = QHBoxLayout()
    connection.addWidget(QLabel('✧  Auto'))
    connection.addWidget(w.button('Siapkan Auto', w.setup_extension))
    connection.addStretch()
    w.connect_button = w.button('Hubungkan', w.connect_player)
    w.connect_button.setObjectName('primary')
    connection.addWidget(w.connect_button)
    connection.addWidget(w.button('Putuskan', w.disconnect_player))
    main_layout.addLayout(connection)
    card, card_layout = box('card', 17, 8)
    card.setFixedHeight(142)
    card_row = QHBoxLayout()
    cover = QLabel()
    cover.setPixmap(artwork())
    cover.setFixedSize(106, 106)
    cover.setToolTip('Placeholder sampul; bukan artwork lagu')
    card_row.addWidget(cover)
    metadata = QVBoxLayout()
    metadata.addWidget(label('DI RUANG DENGARMU', 'eyebrow'))
    w.song = label('Menunggu pemutar', 'song')
    w.song.setFixedHeight(58)
    w.artist_label = label('Hubungkan pemutar untuk mulai.', 'muted')
    w.artist_label.setFixedHeight(24)
    metadata.addWidget(w.song)
    metadata.addWidget(w.artist_label)
    card_row.addLayout(metadata, 1)
    card_layout.addLayout(card_row)
    main_layout.addWidget(card)
    w.sync_status = label('Belum ada lirik', 'muted')
    w.sync_status.setMaximumHeight(60)
    main_layout.addWidget(w.sync_status)
    lyric_header = QHBoxLayout()
    lyric_header.addWidget(label('DI ANTARA NADA', 'eyebrow'), 1)
    lyric_header.addWidget(w.button('Versi lain', lambda: show_page(w, 1)))
    lyric_header.addWidget(w.button('Periksa ulang', w.refresh))
    main_layout.addLayout(lyric_header)
    w.lyrics_list = QListWidget()
    w.lyrics_list.setWordWrap(True)
    w.lyrics_list.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
    if not high_contrast():
        w.lyrics_list.setItemDelegate(LyricDelegate(w.lyrics_list))
    w.lyrics_list.setTextElideMode(Qt.TextElideMode.ElideNone)
    w.lyrics_list.setVerticalScrollMode(QAbstractItemView.ScrollMode.ScrollPerPixel)
    w.lyrics_list.setMinimumHeight(60)
    w.lyrics_list.itemDoubleClicked.connect(w.seek_line)
    main_layout.addWidget(w.lyrics_list, 1)
    progress = QHBoxLayout()
    w.position = QLabel('0:00')
    w.timeline = ThinSlider(Qt.Orientation.Horizontal)
    w.timeline.setAccessibleName('Posisi pemutar')
    w.timeline.setRange(0, 1000)
    w.timeline.sliderReleased.connect(lambda: w.command('seek', w.timeline.value()/1000 * (w.track or {}).get('duration', 0)))
    w.duration_label = QLabel('0:00')
    progress.addWidget(w.position)
    progress.addWidget(w.timeline, 1)
    progress.addWidget(w.duration_label)
    fixed_main.addLayout(progress)
    playback = QHBoxLayout()
    playback.addWidget(w.button('↥  Impor LRC', w.import_lrc))
    playback.addStretch()
    w.play = w.button('▶', lambda: w.command('toggle'))
    w.play.setAccessibleName('Play / pause')
    w.play.setObjectName('play')
    w.play.setFixedSize(46, 46)
    playback.addWidget(w.play)
    playback.addStretch()
    playback.addWidget(label('WAKTU PEMUTAR', 'eyebrow'))
    fixed_main.addLayout(playback)
    # Search/version selection keeps the same callbacks and data objects.
    search_page, search_layout = box('', 0, 16)
    search_layout.addWidget(label('Temukan kata yang kamu cari.', 'heading'))
    search_layout.addWidget(label('Cari di LRCLIB, pilih versi lain, atau impor LRC UTF-8.', 'muted'))
    w.query = QLineEdit()
    w.query.setPlaceholderText('Judul lagu dan artis')
    w.query.setAccessibleName('Cari judul dan artis')
    w.query.returnPressed.connect(w.search)
    search_layout.addWidget(w.query)
    search_layout.addWidget(w.button('Cari lirik', w.search))
    search_layout.addWidget(label('VERSI LIRIK', 'eyebrow'))
    w.versions = QComboBox()
    w.versions.setSizeAdjustPolicy(QComboBox.SizeAdjustPolicy.AdjustToMinimumContentsLengthWithIcon)
    w.versions.setMinimumContentsLength(12)
    w.versions.setMinimumWidth(0)
    w.versions.setAccessibleName('Pilihan versi lirik')
    search_layout.addWidget(w.versions)
    search_layout.addWidget(w.button('Pakai versi', w.choose_version))
    search_layout.addWidget(w.button('Gunakan pilihan otomatis', w.reset_choice))
    search_layout.addWidget(w.button('Impor LRC', w.import_lrc))
    w.search_feedback = label('Hasil pencarian dan pemeriksaan versi akan muncul di sini.', 'muted')
    search_layout.addWidget(w.search_feedback)
    search_layout.addStretch()
    w.pages.addWidget(scroll(search_page))
    appearance, appearance_layout = box('', 0, 20)
    appearance_layout.addWidget(label('Bikin ruang dengarmu sendiri.', 'heading'))
    appearance_layout.addWidget(label('Warna, ukuran dan opasitas langsung diterapkan ke overlay dan disimpan di Windows ini.', 'muted'))
    appearance_layout.addWidget(label('PRATINJAU OVERLAY · TEKS CONTOH', 'eyebrow'))
    w.appearance_preview = label('Setiap kata menemukan nadanya.\n\nLirik tetap dekat.')
    w.appearance_preview.setAlignment(Qt.AlignmentFlag.AlignCenter)
    w.appearance_preview.setMinimumHeight(220)
    appearance_layout.addWidget(w.appearance_preview)
    appearance_layout.addWidget(w.button('▣  Buka overlay', w.toggle_overlay))
    appearance_layout.addWidget(label('Geser bingkai jendela overlay untuk memindahkannya. Saat terkunci, buka kunci melalui system tray Liris.', 'muted'))
    appearance_layout.addStretch()
    w.pages.addWidget(scroll(appearance))
    guide_page, guide_layout = box('', 0, 18)
    guide_layout.addWidget(label('SATU KALI PENGATURAN', 'eyebrow'))
    guide_layout.addWidget(label('Musikmu, sekarang lebih dekat.', 'heading'))
    for title, text in [
        ('YouTube / YouTube Music', '1. Ekstrak seluruh paket ke lokasi tetap. Klik Setup extension.\n2. Di Chrome, Brave atau Edge buka Extensions → Developer mode → Load unpacked. Pilih folder Extension yang dibuka.\n3. Reload tab musik, lalu Hubungkan di Liris. Tidak memerlukan Apple Events.'),
        ('Discord / output sistem Windows', 'Klik Hubungkan, lalu Aktifkan audio secara manual. WASAPI membaca output default, bukan mikrofon. Signature dikirim ke Shazam; percakapan yang diputar dapat ikut dianalisis. Matikan selama percakapan pribadi.'),
        ('Tetap dalam kendalimu', 'Startup, Connect dan reconnect selalu membiarkan audio mati. Matikan tersedia di banner, overlay tidak terkunci, dan tray. Jika paket dipindah, ulangi Setup extension. Posisi hasil audio bersifat perkiraan.')]:
        c, l = box('card')
        l.addWidget(label(title, 'heading'))
        l.addWidget(label(text, 'muted'))
        guide_layout.addWidget(c)
    guide_layout.addWidget(w.button('Setup extension Windows', w.setup_extension))
    guide_layout.addStretch()
    w.pages.addWidget(scroll(guide_page))
    settings, settings_layout = box('settings', 18, 16)
    settings_layout.addWidget(label('SESUAIKAN SUASANA', 'eyebrow'))
    settings_layout.addWidget(label('Warna sorotan', 'muted'))
    colors = QHBoxLayout()
    for name, color in [('Lime', TOKENS['lime']), ('Lavender', TOKENS['lavender']), ('Peach', TOKENS['peach'])]:
        b = w.button('', lambda checked=False, c=color: w.display_setting('color', c))
        b.setAccessibleName(name)
        b.setToolTip(name)
        b.setFixedSize(32, 32)
        if not high_contrast():
            b.setStyleSheet(f'QPushButton {{ background: {color}; border: 2px solid #57634B; border-radius: 16px; }} QPushButton:focus {{ border: 3px solid white; }}')
        else:
            b.setText(name[:1])
        colors.addWidget(b)
    colors.addStretch()
    settings_layout.addLayout(colors)
    for title, name, low, high, value in [
        ('Ukuran lirik overlay', 'font_size', 18, 64, w.store.settings.get('font_size', 30)),
        ('Opasitas overlay', 'opacity', 25, 100, int(w.store.settings.get('opacity', .9)*100))]:
        settings_layout.addWidget(label(title, 'muted'))
        slider = ThinSlider(Qt.Orientation.Horizontal)
        slider.setAccessibleName(title)
        slider.setRange(low, high)
        slider.setValue(value)
        number = QLabel()
        def changed(v, key=name, text=number):
            text.setText(f'{v} px' if key == 'font_size' else f'{v}%')
        changed(value)
        slider.valueChanged.connect(changed)
        slider.valueChanged.connect(lambda v, key=name: w.display_setting(key, v/100 if key == 'opacity' else v))
        settings_layout.addWidget(slider)
        settings_layout.addWidget(number)
    settings_layout.addWidget(label('PAS DI WAKTUNYA', 'eyebrow'))
    settings_layout.addWidget(label('Offset lirik (detik)', 'muted'))
    w.offset = QDoubleSpinBox()
    w.offset.setRange(-10, 10)
    w.offset.setSingleStep(.2)
    w.offset.setDecimals(1)
    w.offset.setAccessibleName('Offset lirik dalam detik')
    w.offset.valueChanged.connect(w.offset_changed)
    settings_layout.addWidget(w.offset)
    settings_layout.addWidget(label('+ lebih cepat · − lebih lambat', 'muted'))
    w.lock_overlay = QCheckBox('Klik menembus')
    w.lock_overlay.setToolTip('Buka kunci melalui system tray Liris')
    w.lock_overlay.toggled.connect(lambda v: w.overlay.set_locked(v))
    settings_layout.addWidget(w.lock_overlay)
    settings_layout.addWidget(w.button('Buka overlay', w.toggle_overlay))
    settings_layout.addWidget(label('Lirik tetap dekat.', 'heading'))
    settings_layout.addWidget(label('Bawa lirik ke atas aplikasi lain tanpa meninggalkan ruang dengarmu.', 'muted'))
    settings_layout.addStretch()
    w.settings_scroll = scroll(settings)
    w.settings_scroll.setFixedWidth(252)
    columns.addWidget(w.settings_scroll)
    w.source = label('YouTube / YouTube Music melalui extension. Audio sistem bersifat opsional.', 'muted')
    w.connection_status = QLabel('Belum terhubung')
    footer = QHBoxLayout()
    footer.addWidget(w.connection_status)
    footer.addWidget(w.source, 1)
    footer.addWidget(QLabel('LRCLIB'))
    content_layout.addLayout(footer)
    w.presentation_timer = QTimer(w)
    w.presentation_timer.timeout.connect(lambda: present(w))
    w.presentation_timer.start(200)
    w._presentation_state = None
    show_page(w, 0)


def show_page(w, index):
    w.pages.setCurrentIndex(index)
    w.page_heading.setText(['Musikmu, kata demi kata.', 'Cari lirik', 'Tampilan', 'Panduan koneksi'][index])
    for i, b in enumerate(w.nav_buttons):
        b.setChecked(i == index)
    w.settings_scroll.setVisible(index != 3)
    if index == 1:
        w.query.setFocus()


def present(w):
    active = w.audio.enabled or w.audio_state.startswith('Menghentikan')
    state = (active, w.audio_state)
    if state != w._presentation_state:
        w._presentation_state = state
        w.audio_banner.setProperty('active', active)
        w.audio_banner.style().unpolish(w.audio_banner)
        w.audio_banner.style().polish(w.audio_banner)
        w.audio_stop.setVisible(active)
        w.audio_enable.setVisible(not active)
        w.audio_detail.setText('Signature dikirim ke Shazam. Output percakapan bisa ikut dianalisis.' if active
                               else 'Aktifkan manual setelah terhubung. Connect/reconnect tidak menyalakan audio.')
    track = w.track or {}
    w.play.setText('Ⅱ' if w.packet and w.packet.get('playing') else '▶')
    w.song.setText(track.get('title') or 'Musik menyala.\nLirik ikut bercerita.')
    w.artist_label.setText(' · '.join(filter(None, [track.get('artist'), track.get('album')])) or 'Hubungkan pemutar untuk mulai mendengarkan.')
    duration = track.get('duration', 0)
    w.duration_label.setText(f'{int(duration)//60}:{int(duration)%60:02d}')
    w.timeline.setEnabled(bool(w.packet) and not w.packet.get('quantized', False) and duration > 0)
    if not w.timeline.isSliderDown():
        w.timeline.setValue(int(min(1, w.clock.value()/duration)*1000) if duration else 0)
    w.search_feedback.setText(w.sync_status.text())
    if not high_contrast():
        w.appearance_preview.setStyleSheet(f'background: #1A1D1D; border-radius: 16px; padding: 24px; color: {w.store.settings.get("color", TOKENS["lime"])}; font-size: {w.store.settings.get("font_size", 30)}px; font-weight: 600;')
    w.overlay.title.setText('LIRIS  /  ' + (track.get('title') or 'Menunggu pemutar'))
    i = w.current_line
    w.overlay.next_line.setText(w.lines[i+1].text if 0 <= i+1 < len(w.lines) else '')


def scroll_active(w, index):
    import ctypes
    from PySide6.QtWidgets import QAbstractItemView
    bar = w.lyrics_list.verticalScrollBar()
    if getattr(w, 'lyric_scroll_animation', None):
        w.lyric_scroll_animation.stop()
    old = bar.value()
    w.lyrics_list.scrollToItem(w.lyrics_list.item(index), QAbstractItemView.ScrollHint.PositionAtCenter)
    target = bar.value()
    enabled = ctypes.c_int(0)
    # If Windows cannot report motion preferences, choose no animation.
    motion = ctypes.windll.user32.SystemParametersInfoW(0x1042, 0, ctypes.byref(enabled), 0) and enabled.value
    if motion and old != target:
        bar.setValue(old)
        w.lyric_scroll_animation = QPropertyAnimation(bar, b'value', w)
        w.lyric_scroll_animation.setDuration(180)
        w.lyric_scroll_animation.setStartValue(old)
        w.lyric_scroll_animation.setEndValue(target)
        w.lyric_scroll_animation.setEasingCurve(QEasingCurve.Type.InOutCubic)
        w.lyric_scroll_animation.start()
    if w.width() < 1100:
        w.stage_scroll.ensureWidgetVisible(w.lyrics_list)
