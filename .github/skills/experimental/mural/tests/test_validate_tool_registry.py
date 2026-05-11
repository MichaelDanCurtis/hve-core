# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Negative-path tests for `_validate_tool_registry`.

The validator runs at module load and short-circuits on the first violation.
Each test mutates exactly one field of an otherwise-valid spec, swaps the
single-entry registry into the module via `monkeypatch.setattr`, and asserts
that calling `_validate_tool_registry()` raises `RuntimeError` with a message
fragment unique to the targeted branch.
"""

from __future__ import annotations

from typing import Any

import pytest


def _valid_spec(handler: Any | None = None) -> dict[str, Any]:
    """Return a fresh `_TOOL_REGISTRY` entry that satisfies every branch."""
    return {
        "title": "Example tool",
        "description": (
            "Single-line summary under 120 chars.\n\n"
            "Detail paragraph that explains the tool in more depth."
        ),
        "input_schema": {
            "type": "object",
            "additionalProperties": False,
            "properties": {"alpha": {"type": "string"}},
            "required": ["alpha"],
        },
        "handler": handler if handler is not None else (lambda _args: None),
        "annotations": {},
    }


def test_valid_spec_passes_validator(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": _valid_spec()})
    mural_module._validate_tool_registry()


def test_b1_title_missing_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    del spec["title"]
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="title must be a non-empty string"):
        mural_module._validate_tool_registry()


def test_b1_title_blank_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["title"] = "   "
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="title must be a non-empty string"):
        mural_module._validate_tool_registry()


def test_b2_description_missing_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    del spec["description"]
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="description must be a non-empty string"):
        mural_module._validate_tool_registry()


def test_b2_description_empty_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["description"] = ""
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="description must be a non-empty string"):
        mural_module._validate_tool_registry()


def test_b3_description_missing_separator_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["description"] = "summary only"
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="must contain a blank-line separator"):
        mural_module._validate_tool_registry()


def test_b4a_summary_empty_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["description"] = "\n\ndetails"
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="summary must be a single non-empty line"):
        mural_module._validate_tool_registry()


def test_b4b_summary_multiline_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["description"] = "line1\nline2\n\ndetails"
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="summary must be a single non-empty line"):
        mural_module._validate_tool_registry()


def test_b5_summary_too_long_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["description"] = ("a" * 121) + "\n\ndetails"
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="summary exceeds 120 chars"):
        mural_module._validate_tool_registry()


def test_b6_details_blank_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["description"] = "summary\n\n   "
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="details must be non-empty"):
        mural_module._validate_tool_registry()


def test_b7_input_schema_not_dict_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["input_schema"] = ["not", "a", "dict"]
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="input_schema must be a dict"):
        mural_module._validate_tool_registry()


def test_b8_input_schema_type_not_object_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["input_schema"]["type"] = "array"
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="input_schema.type must be 'object'"):
        mural_module._validate_tool_registry()


def test_b9_additional_properties_true_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["input_schema"]["additionalProperties"] = True
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="additionalProperties must be False"):
        mural_module._validate_tool_registry()


def test_b9_additional_properties_missing_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    del spec["input_schema"]["additionalProperties"]
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="additionalProperties must be False"):
        mural_module._validate_tool_registry()


def test_b10_properties_not_dict_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["input_schema"]["properties"] = []
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="input_schema.properties must be a dict"):
        mural_module._validate_tool_registry()


def test_b11a_required_not_list_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["input_schema"]["required"] = "alpha"
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="required must be a list of strings"):
        mural_module._validate_tool_registry()


def test_b11b_required_non_string_entry_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["input_schema"]["required"] = ["alpha", 7]
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="required must be a list of strings"):
        mural_module._validate_tool_registry()


def test_b12_required_undeclared_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["input_schema"]["required"] = ["beta"]
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="required references undeclared properties"):
        mural_module._validate_tool_registry()


def test_b13_handler_not_callable_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["handler"] = "not callable"
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="handler must be callable"):
        mural_module._validate_tool_registry()


def test_b13_handler_missing_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    del spec["handler"]
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="handler must be callable"):
        mural_module._validate_tool_registry()


def test_b14_annotations_not_dict_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    spec["annotations"] = []
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="annotations must be a dict"):
        mural_module._validate_tool_registry()


def test_b14_annotations_missing_raises(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    spec = _valid_spec()
    del spec["annotations"]
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", {"x": spec})
    with pytest.raises(RuntimeError, match="annotations must be a dict"):
        mural_module._validate_tool_registry()
