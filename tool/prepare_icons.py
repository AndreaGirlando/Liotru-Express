#!/usr/bin/env python3
"""Produce le sole dimensioni Android dal PNG originale, senza ridisegnarlo.

Richiede Pillow. Eseguire dalla radice: python3 tool/prepare_icons.py
Il PNG usato da Flutter resta una copia byte per byte del file fornito.
"""
from pathlib import Path
import shutil
from PIL import Image, ImageOps

source = Path('assets/Elefante_verde_su_sfondo_blu_notte-removebg-preview.png')
asset = Path('assets/branding/liotru.png')
asset.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(source, asset)
image = Image.open(source).convert('RGBA')
resources = Path('android/app/src/main/res')


def centered(size, content_size, background):
    canvas = Image.new('RGBA', (size, size), background)
    content = ImageOps.contain(image, (content_size, content_size), Image.Resampling.LANCZOS)
    canvas.alpha_composite(content, ((size - content.width) // 2, (size - content.height) // 2))
    return canvas


for density, factor in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
    folder = resources / f'mipmap-{density}'
    folder.mkdir(parents=True, exist_ok=True)
    centered(round(48 * factor), round(40 * factor), '#f3f6f1').save(folder / 'ic_launcher.png', optimize=True)
    # Keep the full elephant inside the adaptive icon's central safe area.
    centered(round(108 * factor), round(66 * factor), (0, 0, 0, 0)).save(folder / 'ic_launcher_foreground.png', optimize=True)

adaptive = resources / 'mipmap-anydpi-v26'
adaptive.mkdir(parents=True, exist_ok=True)
(adaptive / 'ic_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/icon_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''')
(resources / 'values/icon_colors.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="icon_background">#F3F6F1</color>
</resources>
''')
print('PNG originale copiato per Flutter; icone Android legacy e adattive generate.')
