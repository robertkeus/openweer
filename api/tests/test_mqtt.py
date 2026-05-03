"""KNMI MQTT subscriber — pure-function tests for parsing + topic routing."""

from __future__ import annotations

import json

import pytest

from openweer.knmi.datasets import get_dataset
from openweer.knmi.mqtt import KnmiMqttSubscriber, parse_event


def test_parse_event_handles_top_level_payload() -> None:
    payload = json.dumps(
        {
            "datasetName": "radar_forecast",
            "datasetVersion": "2.0",
            "filename": "RAD_NL25_RAC_FM_202604031200.h5",
            "url": "https://knmi.s3.amazonaws.com/x",
        }
    )
    event = parse_event(payload)
    assert event is not None
    assert event.filename == "RAD_NL25_RAC_FM_202604031200.h5"
    assert event.dataset_version == "2.0"


def test_parse_event_handles_nested_data_envelope() -> None:
    payload = json.dumps(
        {
            "specVersion": "1.0",
            "data": {
                "datasetName": "radar_forecast",
                "datasetVersion": "2.0",
                "filename": "x.h5",
            },
        }
    ).encode("utf-8")

    event = parse_event(payload)
    assert event is not None
    assert event.filename == "x.h5"


@pytest.mark.parametrize(
    "payload",
    [
        b"not json",
        json.dumps(["a", "b"]).encode("utf-8"),
        json.dumps({"datasetName": "x"}).encode("utf-8"),  # missing required fields
        b"\xff\xfe\x00bad-utf8",
        12345,
        None,
    ],
)
def test_parse_event_returns_none_on_garbage(payload: object) -> None:
    assert parse_event(payload) is None


def test_subscriber_topics_match_datasets() -> None:
    radar_forecast = get_dataset("radar_forecast")
    radar_observed = get_dataset("radar_observed")

    sub = KnmiMqttSubscriber(
        api_key="test",
        client_id="openweer-test",
        datasets=(radar_forecast, radar_observed),
    )

    assert sub.topics == (
        "dataplatform/file/v1/radar_forecast/2.0/created",
        "dataplatform/file/v1/radar_reflectivity_composites/2.0/created",
    )


def test_subscriber_rejects_empty_api_key() -> None:
    with pytest.raises(ValueError, match="non-empty api_key"):
        KnmiMqttSubscriber(
            api_key="",
            client_id="openweer-test",
            datasets=(get_dataset("radar_forecast"),),
        )


def test_subscriber_rejects_blank_client_id() -> None:
    with pytest.raises(ValueError, match="stable client_id"):
        KnmiMqttSubscriber(
            api_key="x",
            client_id="",
            datasets=(get_dataset("radar_forecast"),),
        )


def test_subscriber_rejects_empty_dataset_list() -> None:
    with pytest.raises(ValueError, match="at least one dataset"):
        KnmiMqttSubscriber(api_key="x", client_id="c", datasets=())
