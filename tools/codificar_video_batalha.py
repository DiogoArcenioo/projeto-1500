"""Codifica as capturas reais do Godot usando o sequenciador nativo do Blender."""
import bpy
from pathlib import Path
RAIZ=Path(__file__).resolve().parents[1]
folder=RAIZ/'exports/revisao_animacoes_batalha/frames'
files=sorted(folder.glob('frame_*.png'))
assert len(files)==180,'A captura precisa terminar antes de codificar'
anterior=bpy.context.window.scene
s=bpy.data.scenes.new('Video_Revisao_Batalha_Final');bpy.context.window.scene=s
editor=s.sequence_editor_create()
editor.use_cache_raw=False;editor.use_cache_final=False
strip=editor.strips.new_image('Capturas reais Godot',str(files[0]),channel=1,frame_start=1)
for f in files[1:]:strip.elements.append(f.name)
strip.frame_final_duration=len(files)
s.frame_start=1;s.frame_end=len(files)
s.render.resolution_x=1280;s.render.resolution_y=720;s.render.resolution_percentage=100;s.render.fps=12
s.render.use_sequencer=True
s.render.image_settings.media_type='VIDEO'
s.render.image_settings.file_format='FFMPEG'
s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264'
s.render.ffmpeg.constant_rate_factor='MEDIUM'
s.view_settings.view_transform='Standard'
s.render.filepath=str(RAIZ/'exports/revisao_animacoes_batalha/movimentos_batalha.mp4')
bpy.ops.render.render(animation=True,scene=s.name)
bpy.context.window.scene=anterior
print('VIDEO_FINAL',s.render.filepath)
