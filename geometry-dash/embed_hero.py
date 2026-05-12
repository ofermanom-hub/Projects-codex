import pillow_heif, base64, io
from PIL import Image

pillow_heif.register_heif_opener()
img = Image.open(r'C:\Users\yotam\Downloads\IMG_4704.HEIC')
img = img.resize((200, 200), Image.LANCZOS)
buf = io.BytesIO()
img.save(buf, 'PNG')
b64 = base64.b64encode(buf.getvalue()).decode()
data_url = "data:image/png;base64," + b64

with open(r'C:\Users\yotam\.claude\projects\geometry-dash\index.html', 'r', encoding='utf-8') as f:
    html = f.read()

old = "// Auto-load local hero image\ntryLoadHero('hero.png');"
new = "tryLoadHero('" + data_url + "');"

if old in html:
    html = html.replace(old, new)
    print("Replaced OK")
else:
    print("MARKER NOT FOUND — searching...")
    idx = html.find("tryLoadHero")
    print(repr(html[idx:idx+80]))

with open(r'C:\Users\yotam\.claude\projects\geometry-dash\index.html', 'w', encoding='utf-8') as f:
    f.write(html)
