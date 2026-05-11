# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Per-type dispatch and atomic-abort tests for `widget create-bulk`."""

from __future__ import annotations

import json
import pathlib
from typing import Any

import pytest
from test_constants import TEST_MURAL_ID


def _record_per_call(
    monkeypatch: pytest.MonkeyPatch,
    mural_module: Any,
    outcomes: list[Any],
) -> list[dict[str, Any]]:
    """Replace ``_authenticated_request`` with a per-call recorder."""
    calls: list[dict[str, Any]] = []
    iterator = iter(outcomes)

    def _fake(method: str, path: str, **kwargs: Any) -> Any:
        calls.append({"method": method, "path": path, **kwargs})
        try:
            outcome = next(iterator)
        except StopIteration as exc:  # pragma: no cover - test misconfiguration
            raise AssertionError(
                f"unexpected extra _authenticated_request call: {method} {path}"
            ) from exc
        if isinstance(outcome, BaseException):
            raise outcome
        return outcome

    monkeypatch.setattr(mural_module, "_authenticated_request", _fake)
    return calls


def test_create_bulk_dispatches_per_type(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    payload_path = tmp_path / "widgets.json"
    payload_path.write_text(
        json.dumps(
            [
                {"type": "textbox", "text": "t"},
                {"type": "sticky-note", "text": "s1"},
                {"type": "sticky note", "text": "s2"},
            ]
        ),
        encoding="utf-8",
    )
    calls = _record_per_call(
        monkeypatch,
        mural_module,
        outcomes=[{"id": "w1"}, {"id": "w2"}, {"id": "w3"}],
    )

    rc = mural_module.main(
        [
            "widget",
            "create-bulk",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(payload_path),
            "--no-author-tag",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    expected_paths = [
        f"/murals/{TEST_MURAL_ID}/widgets/textbox",
        f"/murals/{TEST_MURAL_ID}/widgets/sticky-note",
        f"/murals/{TEST_MURAL_ID}/widgets/sticky-note",
    ]
    assert [(c["method"], c["path"]) for c in calls] == [
        ("POST", p) for p in expected_paths
    ]
    bare = f"/murals/{TEST_MURAL_ID}/widgets"
    assert all(c["path"] != bare for c in calls)
    for call in calls:
        assert "type" not in call["json_body"]
    out = json.loads(capsys.readouterr().out)
    assert out["succeeded"] == [{"id": "w1"}, {"id": "w2"}, {"id": "w3"}]
    assert out["skipped"] == []
    assert out["failed"] == []


def test_create_bulk_atomic_aborts_on_first_failure(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    payload_path = tmp_path / "widgets.json"
    payload_path.write_text(
        json.dumps(
            [
                {"type": "sticky-note", "text": "a"},
                {"type": "sticky-note", "text": "b"},
                {"type": "sticky-note", "text": "c"},
            ]
        ),
        encoding="utf-8",
    )
    calls = _record_per_call(
        monkeypatch,
        mural_module,
        outcomes=[
            {"id": "w1"},
            mural_module.MuralError("boom"),
            {"id": "w3"},
        ],
    )

    rc = mural_module.main(
        [
            "widget",
            "create-bulk",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(payload_path),
            "--atomic",
            "--no-author-tag",
        ]
    )

    assert rc == mural_module.EXIT_TEMPFAIL
    assert len(calls) == 2
    assert all(
        c["path"] == f"/murals/{TEST_MURAL_ID}/widgets/sticky-note" for c in calls
    )
    err = capsys.readouterr().err.strip()
    payload = json.loads(err)
    assert payload["error"] == "bulk_atomic_abort"
    assert payload["aborted"] is True
    assert len(payload["succeeded"]) == 1
    assert len(payload["failed"]) == 1
    assert payload["failed"][0]["error"] == "boom"


def test_create_bulk_dedup_skips_matching_layout_hash_then_dispatches_remainder(
    mural_module: Any,
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: pathlib.Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setattr(
        mural_module,
        "_existing_layout_hashes",
        lambda mural_id, area_id: {"abc123"},
    )
    payload_path = tmp_path / "widgets.json"
    payload_path.write_text(
        json.dumps(
            [
                {
                    "type": "textbox",
                    "text": "skip-me",
                    "areaId": "area-1",
                    "tags": ["auto-layout-hash:abc123"],
                },
                {"type": "textbox", "text": "send-me"},
                {"type": "sticky-note", "text": "send-me-too"},
            ]
        ),
        encoding="utf-8",
    )
    calls = _record_per_call(
        monkeypatch,
        mural_module,
        outcomes=[{"id": "w1"}, {"id": "w2"}],
    )

    rc = mural_module.main(
        [
            "widget",
            "create-bulk",
            "--mural",
            TEST_MURAL_ID,
            "--file",
            str(payload_path),
            "--no-author-tag",
        ]
    )

    assert rc == mural_module.EXIT_SUCCESS
    assert [(c["method"], c["path"]) for c in calls] == [
        ("POST", f"/murals/{TEST_MURAL_ID}/widgets/textbox"),
        ("POST", f"/murals/{TEST_MURAL_ID}/widgets/sticky-note"),
    ]
    out = json.loads(capsys.readouterr().out)
    assert len(out["skipped"]) == 1
    assert out["skipped"][0]["reason"] == "layout_hash_match"
    assert out["skipped"][0]["hash"] == "abc123"
    assert out["skipped"][0]["area_id"] == "area-1"
    assert out["succeeded"] == [{"id": "w1"}, {"id": "w2"}]
    assert out["failed"] == []
