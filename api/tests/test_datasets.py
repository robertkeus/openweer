"""Datasets registry — sanity checks."""

from __future__ import annotations

import pytest

from openweer.knmi.datasets import DATASETS, DatasetKey, get_dataset


@pytest.mark.parametrize("key", list(DATASETS))
def test_every_dataset_has_a_well_formed_topic(key: DatasetKey) -> None:
    ds = get_dataset(key)
    expected = f"dataplatform/file/v1/{ds.name}/{ds.version}/created"
    assert ds.mqtt_topic == expected


@pytest.mark.parametrize("key", list(DATASETS))
def test_every_dataset_has_a_well_formed_files_path(key: DatasetKey) -> None:
    ds = get_dataset(key)
    assert ds.files_path == f"datasets/{ds.name}/versions/{ds.version}/files"


def test_radar_forecast_is_hdf5_with_5min_cadence() -> None:
    ds = get_dataset("radar_forecast")
    assert ds.file_format == "hdf5"
    assert ds.cadence_seconds == 300


def test_dataset_keys_are_unique_and_complete() -> None:
    expected = {"radar_forecast", "radar_observed", "obs_10min", "harmonie"}
    assert set(DATASETS) == expected
