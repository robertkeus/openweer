"""KNMI dataset registry.

Single source of truth for the four datasets OpenWeer consumes. Slugs and versions
are taken from the KNMI catalog at https://dataplatform.knmi.nl/dataset/.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

DatasetKey = Literal[
    "radar_forecast",
    "radar_observed",
    "obs_10min",
    "harmonie",
]

FileFormat = Literal["hdf5", "netcdf", "grib"]


@dataclass(frozen=True, slots=True)
class Dataset:
    """KNMI dataset descriptor."""

    key: DatasetKey
    name: str
    version: str
    file_format: FileFormat
    cadence_seconds: int
    description: str

    @property
    def mqtt_topic(self) -> str:
        """MQTT topic for `created` file events on this dataset."""
        return f"dataplatform/file/v1/{self.name}/{self.version}/created"

    @property
    def files_path(self) -> str:
        """Open Data API path component for listing files."""
        return f"datasets/{self.name}/versions/{self.version}/files"


DATASETS: dict[DatasetKey, Dataset] = {
    "radar_forecast": Dataset(
        key="radar_forecast",
        name="radar_forecast",
        version="2.0",
        file_format="hdf5",
        cadence_seconds=300,
        description="2-hour precipitation nowcast (pySTEPS), 25 frames at 5 min, 1 km grid.",
    ),
    "radar_observed": Dataset(
        key="radar_observed",
        name="radar_reflectivity_composites",
        version="2.0",
        file_format="hdf5",
        cadence_seconds=300,
        description="Observed radar reflectivity composite (Herwijnen + Den Helder).",
    ),
    "obs_10min": Dataset(
        key="obs_10min",
        name="10-minute-in-situ-meteorological-observations",
        version="1.0",
        file_format="netcdf",
        cadence_seconds=600,
        description="10-minute station observations (~50 stations, NL).",
    ),
    "harmonie": Dataset(
        key="harmonie",
        name="harmonie_arome_cy43_p1",
        version="1.0",
        file_format="grib",
        cadence_seconds=10_800,
        description="HARMONIE-AROME deterministic forecast (NL parameters).",
    ),
}


def get_dataset(key: DatasetKey) -> Dataset:
    """Look up a dataset descriptor by short key."""
    return DATASETS[key]


def find_dataset(name: str, version: str) -> Dataset | None:
    """Look up a dataset by its KNMI name + version. Returns None if not configured."""
    for ds in DATASETS.values():
        if ds.name == name and ds.version == version:
            return ds
    return None
