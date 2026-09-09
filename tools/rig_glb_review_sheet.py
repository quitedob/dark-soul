"""Compose Blender rest/posed renders with actual projected armature overlays."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageStat


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    args = parser.parse_args()
    evidence = json.loads(args.evidence.read_text(encoding='utf8'))
    screenshots = args.evidence.parent / 'screenshots'
    font_path = Path('C:/Windows/Fonts/consola.ttf')
    font = ImageFont.truetype(str(font_path), 19) if font_path.exists() else ImageFont.load_default(size=19)
    cells = []
    for model in evidence['models']:
        cell = Image.new('RGB', (1440, 770), '#20252a')
        for column, state in enumerate(('rest', 'posed')):
            record = model[state]
            frame = Image.open(screenshots / record['image']).convert('RGB')
            if max(ImageStat.Stat(frame).stddev) < 3:
                raise ValueError('Blank render: ' + record['image'])
            draw = ImageDraw.Draw(frame)
            for bone in record['bones']:
                color = '#f9bf50' if bone['name'] in record['posed_bones'] else '#64dcf3'
                a, b = tuple(bone['head']), tuple(bone['tail'])
                draw.line([a, b], fill='#14272d', width=5)
                draw.line([a, b], fill=color, width=2)
                draw.ellipse((a[0]-2, a[1]-2, a[0]+2, a[1]+2), fill=color)
            draw.text((12, 12), state.upper(), font=font, fill='white', stroke_width=1, stroke_fill='black')
            cell.paste(frame, (column * 720, 50))
        ImageDraw.Draw(cell).text((12, 12), '%s | %d bones, %d blended meshes' %
                                  (model['file'], model['bones'], model['blended_meshes']), font=font, fill='white')
        path = screenshots / (Path(model['rest']['image']).stem.removesuffix('-rest') + '-review.png')
        cell.save(path)
        model['review_image'] = path.name
        cells.append(cell)
    sheet = Image.new('RGB', (1440, 770 * len(cells)), '#20252a')
    for index, cell in enumerate(cells):
        sheet.paste(cell, (0, index * 770))
    path = screenshots / (evidence['prefix'] + '-sheet.png')
    sheet.save(path)
    args.evidence.write_text(json.dumps(evidence, indent=2) + '\n', encoding='utf8')
    print('RIG_REVIEW_SHEET_OK', len(cells), path)


if __name__ == '__main__':
    main()
