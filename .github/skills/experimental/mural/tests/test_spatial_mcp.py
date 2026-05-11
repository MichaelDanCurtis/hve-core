# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""MCP stdio tests for ``mural_spatial_*`` tools.

Asserts schema registration, additionalProperties enforcement, registry
round-trip behaviour, and ``safe_rect`` normalization for the two spatial
tools exposed via ``_run_mcp_stdio``.
"""

from __future__ import annotations

import io
import json
from typing import Any

import pytest
from test_constants import TEST_MURAL_ID


def _drive(
    mural_module: Any,
    frames: list[dict[str, Any] | bytes],
) -> list[dict[str, Any]]:
    buf = io.BytesIO()
    for frame in frames:
        if isinstance(frame, bytes):
            buf.write(frame)
            if not frame.endswith(b"\n"):
                buf.write(b"\n")
        else:
            buf.write(mural_module._frame_mcp_message(frame))
    buf.seek(0)
    out = io.BytesIO()
    rc = mural_module._run_mcp_stdio(stdin=buf, stdout=out)
    assert rc == mural_module.EXIT_SUCCESS
    out.seek(0)
    responses: list[dict[str, Any]] = []
    for line in out.read().splitlines():
        if not line:
            continue
        responses.append(json.loads(line.decode("utf-8")))
    return responses


def _list_tool(mural_module: Any, name: str) -> dict[str, Any]:
    responses = _drive(
        mural_module,
        [{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}],
    )
    tools = responses[0]["result"]["tools"]
    matched = [t for t in tools if t["name"] == name]
    assert matched, f"tool {name!r} not advertised in tools/list"
    return matched[0]


# ---------------------------------------------------------------------------
# Schema registration
# ---------------------------------------------------------------------------


def test_spatial_widgets_in_shape_registered_with_additional_properties_false(
    mural_module: Any,
) -> None:
    tool = _list_tool(mural_module, "mural_spatial_widgets_in_shape")
    schema = tool["inputSchema"]
    assert schema["additionalProperties"] is False
    assert {"mural_id", "shape_id"} <= set(schema["required"])
    assert tool.get("annotations", {}).get("readOnlyHint") is True


def test_spatial_widgets_in_region_registered_with_additional_properties_false(
    mural_module: Any,
) -> None:
    tool = _list_tool(mural_module, "mural_spatial_widgets_in_region")
    schema = tool["inputSchema"]
    assert schema["additionalProperties"] is False
    assert {"mural_id", "x", "y", "w", "h"} <= set(schema["required"])
    assert tool.get("annotations", {}).get("readOnlyHint") is True


# ---------------------------------------------------------------------------
# additionalProperties enforcement
# ---------------------------------------------------------------------------


def test_spatial_widgets_in_shape_rejects_extra_property(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_widgets_in_shape",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "shape_id": "shape1",
                        "unexpected": "value",
                    },
                },
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602
    assert err["data"] == {"path": "$.arguments.unexpected"}


def test_spatial_widgets_in_region_rejects_extra_property(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_widgets_in_region",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "x": 0,
                        "y": 0,
                        "w": 100,
                        "h": 100,
                        "unexpected": 1,
                    },
                },
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602
    assert err["data"] == {"path": "$.arguments.unexpected"}


# ---------------------------------------------------------------------------
# Registry round-trip via override pattern
# ---------------------------------------------------------------------------


def test_spatial_widgets_in_shape_round_trip_emits_filtered_widgets(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_handler(arguments: dict[str, Any]) -> Any:
        captured["arguments"] = arguments
        return [{"id": "w-1", "x": 5, "y": 5}]

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_spatial_widgets_in_shape"])
    spec["handler"] = fake_handler
    registry["mural_spatial_widgets_in_shape"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 4,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_widgets_in_shape",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "shape_id": "shape1",
                        "mode": "bbox",
                        "rotation_aware": True,
                    },
                },
            },
        ],
    )

    result = responses[0]["result"]
    assert result["isError"] is False
    payload = json.loads(result["content"][0]["text"])
    assert payload == [{"id": "w-1", "x": 5, "y": 5}]
    assert captured["arguments"] == {
        "mural_id": TEST_MURAL_ID,
        "shape_id": "shape1",
        "mode": "bbox",
        "rotation_aware": True,
    }


def test_spatial_widgets_in_region_round_trip_normalizes_negative_dimensions(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Negative w/h are valid against the schema (numbers, no minimum) and the
    # handler must funnel them through ``safe_rect`` so the resulting region
    # has positive width/height. Capture the region the handler computes.
    captured: dict[str, Any] = {}

    def _fake_paginate(method: str, path: str, **kwargs: Any):
        return iter([])

    def _fake_widgets_in_region(widgets, region, *, mode):
        captured["region"] = region
        captured["mode"] = mode
        return []

    monkeypatch.setattr(mural_module, "_paginate", _fake_paginate)
    monkeypatch.setattr(
        mural_module, "widgets_in_region", _fake_widgets_in_region
    )

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 5,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_widgets_in_region",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "x": 0,
                        "y": 0,
                        "w": -100,
                        "h": -100,
                    },
                },
            },
        ],
    )

    result = responses[0]["result"]
    assert result["isError"] is False
    region = captured["region"]
    assert region["w"] == 100
    assert region["h"] == 100
    # Origin is shifted so the geometric footprint matches the signed input.
    assert region["x"] == -100
    assert region["y"] == -100
    assert captured["mode"] == "center"


# ---------------------------------------------------------------------------
# pairwise_overlaps: registration, additionalProperties, registry round-trip
# ---------------------------------------------------------------------------


def test_spatial_pairwise_overlaps_registered_with_additional_properties_false(
    mural_module: Any,
) -> None:
    tool = _list_tool(mural_module, "mural_spatial_pairwise_overlaps")
    schema = tool["inputSchema"]
    assert schema["additionalProperties"] is False
    assert {"mural_id"} <= set(schema["required"])
    assert tool.get("annotations", {}).get("readOnlyHint") is True


def test_spatial_pairwise_overlaps_rejects_extra_property(
    mural_module: Any,
) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 6,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_pairwise_overlaps",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "unexpected": "value",
                    },
                },
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602
    assert err["data"] == {"path": "$.arguments.unexpected"}


def test_spatial_pairwise_overlaps_round_trip_emits_pairs(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_handler(arguments: dict[str, Any]) -> Any:
        captured["arguments"] = arguments
        return [{"a": "w-1", "b": "w-2"}]

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_spatial_pairwise_overlaps"])
    spec["handler"] = fake_handler
    registry["mural_spatial_pairwise_overlaps"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 7,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_pairwise_overlaps",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "predicate": "contains",
                        "rotation_aware": True,
                    },
                },
            },
        ],
    )

    result = responses[0]["result"]
    assert result["isError"] is False
    payload = json.loads(result["content"][0]["text"])
    assert payload == [{"a": "w-1", "b": "w-2"}]
    assert captured["arguments"] == {
        "mural_id": TEST_MURAL_ID,
        "predicate": "contains",
        "rotation_aware": True,
    }


# ---------------------------------------------------------------------------
# spatial cluster: registration, additionalProperties, registry round-trip
# ---------------------------------------------------------------------------


def test_spatial_cluster_registered_with_additional_properties_false(
    mural_module: Any,
) -> None:
    tool = _list_tool(mural_module, "mural_spatial_cluster")
    schema = tool["inputSchema"]
    assert schema["additionalProperties"] is False
    assert {"mural_id"} <= set(schema["required"])
    assert tool.get("annotations", {}).get("readOnlyHint") is True


def test_spatial_cluster_rejects_extra_property(
    mural_module: Any,
) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 8,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_cluster",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "unexpected": "value",
                    },
                },
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602
    assert err["data"] == {"path": "$.arguments.unexpected"}


def test_spatial_cluster_round_trip_emits_member_groups(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_handler(arguments: dict[str, Any]) -> Any:
        captured["arguments"] = arguments
        return [{"members": ["w-1", "w-2", "w-3"]}]

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_spatial_cluster"])
    spec["handler"] = fake_handler
    registry["mural_spatial_cluster"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 9,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_cluster",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "eps_px": 75.0,
                        "min_samples": 3,
                    },
                },
            },
        ],
    )

    result = responses[0]["result"]
    assert result["isError"] is False
    payload = json.loads(result["content"][0]["text"])
    assert payload == [{"members": ["w-1", "w-2", "w-3"]}]
    assert captured["arguments"] == {
        "mural_id": TEST_MURAL_ID,
        "eps_px": 75.0,
        "min_samples": 3,
    }


# ---------------------------------------------------------------------------
# spatial sort-along-axis: registration, additionalProperties, axis enum,
# registry round-trip
# ---------------------------------------------------------------------------


def test_spatial_sort_along_axis_registered_with_additional_properties_false(
    mural_module: Any,
) -> None:
    tool = _list_tool(mural_module, "mural_spatial_sort_along_axis")
    schema = tool["inputSchema"]
    assert schema["additionalProperties"] is False
    assert {"mural_id"} <= set(schema["required"])
    assert tool.get("annotations", {}).get("readOnlyHint") is True
    assert schema["properties"]["axis"]["enum"] == ["x", "y", "diagonal"]


def test_spatial_sort_along_axis_rejects_extra_property(
    mural_module: Any,
) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 10,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_sort_along_axis",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "unexpected": "value",
                    },
                },
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602
    assert err["data"] == {"path": "$.arguments.unexpected"}


def test_spatial_sort_along_axis_rejects_invalid_axis_enum(
    mural_module: Any,
) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 11,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_sort_along_axis",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "axis": "z",
                    },
                },
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602


def test_spatial_sort_along_axis_round_trip_emits_ordered_widgets(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_handler(arguments: dict[str, Any]) -> Any:
        captured["arguments"] = arguments
        return [{"id": "a"}, {"id": "b"}, {"id": "c"}]

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_spatial_sort_along_axis"])
    spec["handler"] = fake_handler
    registry["mural_spatial_sort_along_axis"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 12,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_sort_along_axis",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "axis": "diagonal",
                        "origin_x": 5.0,
                        "origin_y": -2.0,
                    },
                },
            },
        ],
    )

    result = responses[0]["result"]
    assert result["isError"] is False
    payload = json.loads(result["content"][0]["text"])
    assert payload == [{"id": "a"}, {"id": "b"}, {"id": "c"}]
    assert captured["arguments"] == {
        "mural_id": TEST_MURAL_ID,
        "axis": "diagonal",
        "origin_x": 5.0,
        "origin_y": -2.0,
    }


# ---------------------------------------------------------------------------
# spatial arrow-graph: registration, additionalProperties, format enum,
# registry round-trip
# ---------------------------------------------------------------------------


def test_spatial_arrow_graph_registered_with_additional_properties_false(
    mural_module: Any,
) -> None:
    tool = _list_tool(mural_module, "mural_spatial_arrow_graph")
    schema = tool["inputSchema"]
    assert schema["additionalProperties"] is False
    assert {"mural_id"} <= set(schema["required"])
    assert tool.get("annotations", {}).get("readOnlyHint") is True
    assert schema["properties"]["format"]["enum"] == ["summary", "full", "dot"]


def test_spatial_arrow_graph_rejects_extra_property(
    mural_module: Any,
) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 20,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_arrow_graph",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "unexpected": "value",
                    },
                },
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602
    assert err["data"] == {"path": "$.arguments.unexpected"}


def test_spatial_arrow_graph_rejects_invalid_format_enum(
    mural_module: Any,
) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 21,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_arrow_graph",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "format": "graphml",
                    },
                },
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602


def test_spatial_arrow_graph_round_trip_emits_summary(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_handler(arguments: dict[str, Any]) -> Any:
        captured["arguments"] = arguments
        return {
            "nodes": ["a", "b"],
            "edges": [{"id": "e1", "source": "a", "target": "b"}],
            "stats": {"node_count": 2, "edge_count": 1, "is_dag": True},
        }

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_spatial_arrow_graph"])
    spec["handler"] = fake_handler
    registry["mural_spatial_arrow_graph"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 22,
                "method": "tools/call",
                "params": {
                    "name": "mural_spatial_arrow_graph",
                    "arguments": {
                        "mural_id": TEST_MURAL_ID,
                        "snap_radius": 32.0,
                        "format": "summary",
                    },
                },
            },
        ],
    )

    result = responses[0]["result"]
    assert result["isError"] is False
    payload = json.loads(result["content"][0]["text"])
    assert payload["edges"] == [{"id": "e1", "source": "a", "target": "b"}]
    assert payload["stats"]["is_dag"] is True
    assert captured["arguments"] == {
        "mural_id": TEST_MURAL_ID,
        "snap_radius": 32.0,
        "format": "summary",
    }
