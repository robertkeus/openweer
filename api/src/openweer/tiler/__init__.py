"""Tile generator — turns KNMI radar HDF5 files into XYZ PNG tiles + a manifest."""

from openweer.tiler.colormap import RAIN_COLORMAP, apply_rain_colormap
from openweer.tiler.manifest import Frame, FrameKind, FramesManifest
from openweer.tiler.pipeline import RadarTilePipeline, render_radar_file
from openweer.tiler.radar_hdf5 import RadarSubImage, read_radar_hdf5

__all__ = [
    "RAIN_COLORMAP",
    "Frame",
    "FrameKind",
    "FramesManifest",
    "RadarSubImage",
    "RadarTilePipeline",
    "apply_rain_colormap",
    "read_radar_hdf5",
    "render_radar_file",
]
