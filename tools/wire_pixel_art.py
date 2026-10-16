"""Wire generated rasters while preserving old source art and code backups.

Assets.texture keeps all logical IDs and cached lookups. Direct resource refs
are redirected explicitly, including AtlasTexture/SpriteFrames dependencies.
"""
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'godot/assets/images'
BACKUP=ROOT/'tmp/pixel-pass/baseline/files'


def main():
    records=json.loads((ART/'pixel/manifest.json').read_text())
    changes=0
    for directory in ('scenes','ui','autoload','assets/shaders'):
        for path in (ROOT/'godot'/directory).rglob('*'):
            if path.suffix not in ('.gd','.tscn','.tres'):continue
            old=path.read_text(encoding='utf8')
            new=old
            for src,entry in records.items():
                new=new.replace('res://assets/images/'+src,'res://assets/images/'+entry['path'])
            for filename in ('DTM-Sans.otf','DTM-Mono.otf','Tiny5-Regular.ttf'):
                new=new.replace('res://assets/font/'+filename,'res://assets/font/pixel/casino.fnt')
            # Pixel sources must never acquire interpolated edges at runtime.
            new=new.replace('CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS','CanvasItem.TEXTURE_FILTER_NEAREST')
            new=new.replace('CanvasItem.TEXTURE_FILTER_LINEAR','CanvasItem.TEXTURE_FILTER_NEAREST')
            if path.suffix in ('.tscn','.tres'):
                new=re.sub(r'^texture_filter = [2-6]$', 'texture_filter = 1',new,flags=re.M)
                new=re.sub(r'uid="uid://[^"]+" (?=path="res://assets/images/pixel/)', '',new)
                new=re.sub(r'uid="uid://[^"]+" (?=path="res://assets/font/pixel/)', '',new)
            if new!=old:
                backup=BACKUP/path.relative_to(ROOT)
                if not backup.exists():
                    backup.parent.mkdir(parents=True,exist_ok=True)
                    backup.write_text(old,encoding='utf8',newline='\n')
                path.write_text(new,encoding='utf8',newline='\n')
                changes+=1
    print(f'Wired generated art / nearest sampling in {changes} files; originals backed up')


if __name__=='__main__':main()
