# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""MCP stdio server tests for mural.py."""

from __future__ import annotations

import io
import json
from typing import Any

import pytest


def _drive(
    mural_module: Any,
    frames: list[dict[str, Any] | bytes],
) -> list[dict[str, Any]]:
    """Drive `_run_mcp_stdio` with a sequence of NDJSON frames or raw bytes."""
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


def test_initialize_returns_preferred_protocol(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {"protocolVersion": mural_module._MCP_PROTOCOL_PREFERRED},
            },
        ],
    )

    assert len(responses) == 1
    res = responses[0]["result"]
    assert res["protocolVersion"] == mural_module._MCP_PROTOCOL_PREFERRED
    assert res["serverInfo"] == mural_module._MCP_SERVER_INFO
    assert res["capabilities"] == mural_module._MCP_CAPABILITIES


def test_initialize_falls_back_when_unknown_protocol_omitted(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
        ],
    )

    expected_version = mural_module._MCP_PROTOCOL_FALLBACK
    assert responses[0]["result"]["protocolVersion"] == expected_version


def test_initialize_rejects_unsupported_protocol(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {"protocolVersion": "1999-01-01"},
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602
    assert err["data"] == {"path": "$.protocolVersion"}


def test_notifications_initialized_does_not_reply(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
        ],
    )

    assert responses == []


def test_tools_list_returns_registered_tools(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        ],
    )

    tools = responses[0]["result"]["tools"]
    names = {tool["name"] for tool in tools}
    assert "mural_workspace_list" in names
    assert "mural_widget_create_sticky_note" in names
    for tool in tools:
        assert tool["inputSchema"]["additionalProperties"] is False


def test_tools_call_happy_path(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_handler(arguments: dict[str, Any]) -> Any:
        captured["arguments"] = arguments
        return [{"id": "ws-1", "name": "Test"}]

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_workspace_list"])
    spec["handler"] = fake_handler
    registry["mural_workspace_list"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {"name": "mural_workspace_list", "arguments": {}},
            },
        ],
    )

    result = responses[0]["result"]
    assert result["isError"] is False
    payload = json.loads(result["content"][0]["text"])
    assert payload == [{"id": "ws-1", "name": "Test"}]
    assert captured["arguments"] == {}


def test_tools_call_handler_error_returns_iserror(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    def boom(_arguments: dict[str, Any]) -> Any:
        raise mural_module.MuralAPIError(
            status=404,
            code="NOT_FOUND",
            message="missing",
            request_id="req-1",
        )

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_workspace_get"])
    spec["handler"] = boom
    registry["mural_workspace_get"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 4,
                "method": "tools/call",
                "params": {
                    "name": "mural_workspace_get",
                    "arguments": {"workspace": "ws-1"},
                },
            },
        ],
    )

    result = responses[0]["result"]
    assert result["isError"] is True
    payload = json.loads(result["content"][0]["text"])
    assert payload["error"] == "NOT_FOUND"
    assert payload["status"] == 404


def test_tools_call_invalid_params_returns_minus_32602(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 5,
                "method": "tools/call",
                "params": {"name": "unknown_tool", "arguments": {}},
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32602
    assert err["data"] == {"path": "$.name"}


def test_unknown_method_returns_minus_32601(mural_module: Any) -> None:
    responses = _drive(
        mural_module,
        [
            {"jsonrpc": "2.0", "id": 6, "method": "nope/please"},
        ],
    )

    assert responses[0]["error"]["code"] == -32601


def test_malformed_json_returns_minus_32700_and_loop_continues(
    mural_module: Any,
) -> None:
    responses = _drive(
        mural_module,
        [
            b"not-json{",
            {"jsonrpc": "2.0", "id": 7, "method": "tools/list"},
        ],
    )

    assert responses[0]["error"]["code"] == -32700
    assert responses[0]["id"] is None
    assert "tools" in responses[1]["result"]


def test_handler_exception_returns_minus_32603(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    def explode(_arguments: dict[str, Any]) -> Any:
        raise RuntimeError("oops")

    registry = dict(mural_module._TOOL_REGISTRY)
    spec = dict(registry["mural_workspace_list"])
    spec["handler"] = explode
    registry["mural_workspace_list"] = spec
    monkeypatch.setattr(mural_module, "_TOOL_REGISTRY", registry)

    responses = _drive(
        mural_module,
        [
            {
                "jsonrpc": "2.0",
                "id": 8,
                "method": "tools/call",
                "params": {"name": "mural_workspace_list", "arguments": {}},
            },
        ],
    )

    err = responses[0]["error"]
    assert err["code"] == -32603
    assert err["message"] == "internal error"


def test_frame_round_trip(mural_module: Any) -> None:
    msg = {"jsonrpc": "2.0", "id": 1, "method": "ping"}
    framed = mural_module._frame_mcp_message(msg)
    assert framed.endswith(b"\n")
    parsed = mural_module._parse_mcp_frame(framed)
    assert parsed == msg


def test_parse_blank_line_returns_none(mural_module: Any) -> None:
    assert mural_module._parse_mcp_frame(b"\n") is None
    assert mural_module._parse_mcp_frame(b"   \n") is None


# ---------------------------------------------------------------------------
# Phase 4: oversized frames, dry-run preview, elicitation decline, alt_text
# ---------------------------------------------------------------------------


def test_oversized_frame_returns_invalid_request_then_recovers(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Step 4.2: oversized frame yields -32600; loop continues."""
    monkeypatch.setattr(mural_module, "MURAL_MAX_FRAME_BYTES", 1024)
    monkeypatch.setattr(mural_module._read_frame, "__defaults__", (1024,))

    huge = b"x" * 4096 + b"\n"
    initialize = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {"protocolVersion": mural_module._MCP_PROTOCOL_PREFERRED},
    }

    responses = _drive(mural_module, [huge, initialize])

    assert len(responses) >= 2
    first = responses[0]
    assert first.get("error", {}).get("code") == -32600
    second = next((r for r in responses if r.get("id") == 1), None)
    assert second is not None
    assert (
        second["result"]["protocolVersion"]
        == mural_module._MCP_PROTOCOL_PREFERRED
    )


def test_widget_create_image_requires_alt_text(mural_module: Any) -> None:
    """Step 4.9: future schema must require alt_text for accessibility."""
    init_msg = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {"protocolVersion": mural_module._MCP_PROTOCOL_PREFERRED},
    }
    call_msg = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": "mural_widget_create_image",
            "arguments": {
                "mural": "workspace1.mural-abc",
                "file": "/tmp/missing.png",
                "x": 0,
                "y": 0,
            },
        },
    }

    responses = _drive(mural_module, [init_msg, call_msg])
    call_resp = next((r for r in responses if r.get("id") == 2), None)
    assert call_resp is not None
    error = call_resp.get("error")
    assert error is not None, call_resp
    assert error.get("code") == -32602
    assert "alt_text" in error.get("message", "")


def test_destructive_tool_dry_run_preview_skips_http(mural_module: Any) -> None:
    """Step 4.11: dry_run on a destructive tool returns preview without HTTP."""
    init_msg = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {"protocolVersion": mural_module._MCP_PROTOCOL_PREFERRED},
    }
    call_msg = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": "mural_widget_delete",
            "arguments": {
                "mural": "workspace1.mural-abc",
                "widget": "w-1",
                "dry_run": True,
            },
        },
    }

    responses = _drive(mural_module, [init_msg, call_msg])
    call_resp = next((r for r in responses if r.get("id") == 2), None)
    assert call_resp is not None
    result = call_resp["result"]
    assert result.get("isError") is False
    text = result["content"][0]["text"]
    parsed = json.loads(text)
    assert parsed["dry_run"] is True
    assert parsed["tool"] == "mural_widget_delete"
    assert parsed["arguments"]["widget"] == "w-1"


def test_destructive_tool_elicitation_decline_returns_error(
    mural_module: Any,
) -> None:
    """Step 4.11: when elicitation hook declines, tool call returns isError:True."""
    mural_module._ELICITATION_HOOK = lambda _name, _args: False
    original_require_scope = mural_module._require_scope
    mural_module._require_scope = lambda *a, **kw: None
    try:
        init_msg = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": mural_module._MCP_PROTOCOL_PREFERRED,
                "capabilities": {"elicitation": {}},
            },
        }
        call_msg = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "mural_widget_delete",
                "arguments": {
                    "mural": "workspace1.mural-abc",
                    "widget": "w-1",
                    "dry_run": False,
                },
            },
        }
        responses = _drive(mural_module, [init_msg, call_msg])
    finally:
        mural_module._require_scope = original_require_scope
        mural_module._ELICITATION_HOOK = None
        mural_module._CLIENT_CAPABILITIES.pop("elicitation", None)
    call_resp = next((r for r in responses if r.get("id") == 2), None)
    assert call_resp is not None
    result = call_resp["result"]
    assert result.get("isError") is True
    text = result["content"][0]["text"]
    parsed = json.loads(text)
    assert parsed["error"] == "elicitation_declined"



# ---------------------------------------------------------------------------
# Phase 2: bulk widgets, mural duplicate/clone-with-tags, templates, poll,
# archive/unarchive — registry shape + handler behavior
# ---------------------------------------------------------------------------


_PHASE2_TOOLS = {
    "mural_widget_create_bulk": {"destructive": True, "creates": True},
    "mural_mural_duplicate": {"destructive": True, "creates": True},
    "mural_clone_with_tags": {"destructive": True, "creates": True},
    "mural_template_instantiate": {"destructive": True, "creates": True},
    "mural_template_create": {"destructive": True, "creates": True},
    "mural_mural_poll": {"destructive": False, "creates": False},
    "mural_archive": {"destructive": True, "creates": False},
    "mural_unarchive": {"destructive": True, "creates": False},
    "mural_room_create": {"destructive": True, "creates": True},
}


@pytest.mark.parametrize("tool_name,expected", list(_PHASE2_TOOLS.items()))
def test_phase2_tools_registered_with_expected_flags(
    mural_module: Any, tool_name: str, expected: dict[str, bool]
) -> None:
    spec = mural_module._TOOL_REGISTRY[tool_name]
    assert callable(spec["handler"])
    schema = spec["input_schema"]
    assert schema["additionalProperties"] is False
    assert spec.get("destructive", False) is expected["destructive"]
    assert spec.get("creates", False) is expected["creates"]


def test_tool_widget_create_bulk_posts_widgets(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[dict[str, Any]] = []
    counter = {"n": 0}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        counter["n"] += 1
        calls.append({"method": method, "path": path, **kwargs})
        return {"id": f"w{counter['n']}"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    result = mural_module._tool_widget_create_bulk(
        {
            "mural": "workspace1.mural-abc123",
            "widgets": [
                {"type": "sticky-note", "text": "a"},
                {"type": "textbox", "text": "b"},
            ],
            "no_author_tag": True,
        }
    )

    assert len(calls) == 2
    assert [c["method"] for c in calls] == ["POST", "POST"]
    assert [c["path"] for c in calls] == [
        "/murals/workspace1.mural-abc123/widgets/sticky-note",
        "/murals/workspace1.mural-abc123/widgets/textbox",
    ]
    for c in calls:
        assert "type" not in c["json_body"]
    assert result["succeeded"] == [{"id": "w1"}, {"id": "w2"}]
    assert result["skipped"] == []


def test_tool_mural_duplicate_returns_new_id(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda *a, **kw: {"id": "workspace1.mural-new"},
    )

    result = mural_module._tool_mural_duplicate(
        {"mural": "workspace1.mural-abc123"}
    )
    assert result == {
        "new_mural_id": "workspace1.mural-new",
        "source_mural_id": "workspace1.mural-abc123",
    }


def test_tool_clone_with_tags_replays_manifest(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    new_id = "workspace1.mural-clone1"

    monkeypatch.setattr(
        mural_module, "_duplicate_mural", lambda _src: new_id
    )
    monkeypatch.setattr(
        mural_module,
        "_read_tag_manifest",
        lambda _src: [{"text": "red", "color": "#ff0000"}, {"text": "blue"}],
    )
    captured_manifest: dict[str, Any] = {}

    def fake_ensure(mural_id: str, manifest: list[Any]) -> dict[str, str]:
        captured_manifest["mural_id"] = mural_id
        captured_manifest["manifest"] = manifest
        return {entry["text"]: f"tag-{i}" for i, entry in enumerate(manifest)}

    monkeypatch.setattr(mural_module, "_ensure_tag_manifest", fake_ensure)

    result = mural_module._tool_clone_with_tags(
        {"mural": "workspace1.mural-abc123"}
    )

    assert captured_manifest["mural_id"] == new_id
    assert result["new_mural_id"] == new_id
    assert result["source_mural_id"] == "workspace1.mural-abc123"
    assert result["tag_count"] == 2
    assert result["tag_map"] == {"red": "tag-0", "blue": "tag-1"}
    assert result["warnings"] == [
        "widget ids are not preserved across mural duplication"
    ]


def test_tool_template_instantiate_requires_template(
    mural_module: Any,
) -> None:
    with pytest.raises(mural_module.MCPInvalidParamsError):
        mural_module._tool_template_instantiate({"template": ""})
    with pytest.raises(mural_module.MCPInvalidParamsError):
        mural_module._tool_template_instantiate({})


def test_tool_template_instantiate_posts_body(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("MURAL_DEFAULT_WORKSPACE", "workspace1")
    captured: dict[str, Any] = {}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        captured.update({"method": method, "path": path, **kwargs})
        return {"id": "new-mural"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    result = mural_module._tool_template_instantiate(
        {"template": "tpl-123", "name": "From Template"}
    )

    assert captured["method"] == "POST"
    assert captured["path"] == "/templates/tpl-123/instantiate"
    assert captured["json_body"] == {
        "workspaceId": "workspace1",
        "name": "From Template",
    }
    assert result == {"id": "new-mural"}


def test_tool_template_create_posts_body(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("MURAL_DEFAULT_WORKSPACE", "workspace1")
    captured: dict[str, Any] = {}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        captured.update({"method": method, "path": path, **kwargs})
        return {"id": "tpl-new"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    result = mural_module._tool_template_create(
        {"mural": "workspace1.mural-abc123", "name": "Saved Template"}
    )

    assert captured["method"] == "POST"
    assert captured["path"] == "/murals/workspace1.mural-abc123/template"
    assert captured["json_body"] == {
        "workspaceId": "workspace1",
        "name": "Saved Template",
    }
    assert result == {"id": "tpl-new"}


def test_tool_mural_poll_requires_condition(mural_module: Any) -> None:
    with pytest.raises(mural_module.MCPInvalidParamsError):
        mural_module._tool_mural_poll(
            {"mural": "workspace1.mural-abc123"}
        )


def test_tool_mural_poll_uses_defaults(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda *a, **kw: {"status": "active"},
    )
    captured: dict[str, Any] = {}

    def fake_poll(
        mural_id: str,
        *,
        interval_s: float,
        timeout_s: float,
        condition: str,
    ) -> Any:
        captured["mural_id"] = mural_id
        captured["interval_s"] = interval_s
        captured["timeout_s"] = timeout_s
        captured["condition"] = condition
        return {"matched": True, "attempts": 1, "condition": condition, "mural": {}}

    monkeypatch.setattr(mural_module, "_poll_mural", fake_poll)

    result = mural_module._tool_mural_poll(
        {"mural": "workspace1.mural-abc123", "condition": "status==active"}
    )

    assert captured["interval_s"] == mural_module.POLL_DEFAULT_INTERVAL_S
    assert captured["timeout_s"] == mural_module.POLL_DEFAULT_TIMEOUT_S
    assert result["matched"] is True


def test_tool_mural_archive_patches_status(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        captured.update({"method": method, "path": path, **kwargs})
        return {"id": "workspace1.mural-abc123", "status": "archived"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    mural_module._tool_mural_archive({"mural": "workspace1.mural-abc123"})
    assert captured["method"] == "PATCH"
    assert captured["path"] == "/murals/workspace1.mural-abc123"
    assert captured["json_body"] == {"status": "archived"}


def test_tool_mural_unarchive_patches_status(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        captured.update({"method": method, "path": path, **kwargs})
        return {"id": "workspace1.mural-abc123", "status": "active"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    mural_module._tool_mural_unarchive({"mural": "workspace1.mural-abc123"})
    assert captured["method"] == "PATCH"
    assert captured["path"] == "/murals/workspace1.mural-abc123"
    assert captured["json_body"] == {"status": "active"}


def test_tool_room_create_posts_to_workspace(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        captured.update({"method": method, "path": path, **kwargs})
        return {"id": "r-new", "name": "Live Test"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    result = mural_module._tool_room_create(
        {
            "workspace": "ws1",
            "name": "Live Test",
            "type": "open",
            "description": "scratch",
        }
    )

    assert captured["method"] == "POST"
    assert captured["path"] == "/rooms"
    assert captured["json_body"] == {
        "workspaceId": "ws1",
        "name": "Live Test",
        "type": "open",
        "description": "scratch",
    }
    assert result == {"id": "r-new", "name": "Live Test"}


def test_tool_room_create_defaults_type_to_private(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        captured.update({"method": method, "path": path, **kwargs})
        return {"id": "r-new"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    mural_module._tool_room_create({"workspace": "ws1", "name": "Solo"})

    assert captured["json_body"] == {
        "workspaceId": "ws1",
        "name": "Solo",
        "type": "private",
    }


def test_tool_mural_create_posts_to_murals(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    captured: dict[str, Any] = {}

    def fake_request(method: str, path: str, **kwargs: Any) -> Any:
        captured.update({"method": method, "path": path, **kwargs})
        return {"id": "ws1.m-new", "title": "Live Mural"}

    monkeypatch.setattr(mural_module, "_authenticated_request", fake_request)

    result = mural_module._tool_mural_create(
        {"room": "1778094575426809", "title": "Live Mural"}
    )

    assert captured["method"] == "POST"
    assert captured["path"] == "/murals"
    assert captured["json_body"] == {
        "roomId": 1778094575426809,
        "title": "Live Mural",
    }
    assert result == {"id": "ws1.m-new", "title": "Live Mural"}


def test_tool_mural_create_requires_room_and_title(
    mural_module: Any, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        mural_module,
        "_authenticated_request",
        lambda *a, **k: pytest.fail("should not POST"),
    )

    with pytest.raises(mural_module.MCPInvalidParamsError):
        mural_module._tool_mural_create({"title": "x"})

    with pytest.raises(mural_module.MCPInvalidParamsError):
        mural_module._tool_mural_create({"room": "1778094575426809"})


def test_phase2_destructive_tools_dry_run_preview(
    mural_module: Any,
) -> None:
    """Destructive Phase 2 tools return preview without HTTP when dry_run=True."""
    init_msg = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {"protocolVersion": mural_module._MCP_PROTOCOL_PREFERRED},
    }
    call_msg = {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": "mural_archive",
            "arguments": {
                "mural": "workspace1.mural-abc123",
                "dry_run": True,
            },
        },
    }

    responses = _drive(mural_module, [init_msg, call_msg])
    call_resp = next(r for r in responses if r.get("id") == 2)
    result = call_resp["result"]
    assert result.get("isError") is False
    parsed = json.loads(result["content"][0]["text"])
    assert parsed["dry_run"] is True
    assert parsed["tool"] == "mural_archive"


# ---------------------------------------------------------------------------
# Auth status contract (MCP)
# ---------------------------------------------------------------------------

AUTH_STATUS_UNAUTHENTICATED_KEYS = frozenset(
    {"authenticated", "token_store", "credential_file", "credential_file_exists"}
)
AUTH_STATUS_AUTHENTICATED_KEYS = frozenset(
    AUTH_STATUS_UNAUTHENTICATED_KEYS
    | {"profile", "granted_scopes", "expires_at", "has_refresh_token"}
)


def test_tool_auth_status_unauthenticated_contract(
    mural_module: Any,
    tmp_path: Any,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """`_tool_auth_status` returns unauthenticated key set when store is empty."""
    from test_constants import ENV_ENV_FILE, ENV_TOKEN_STORE

    monkeypatch.setenv(ENV_TOKEN_STORE, str(tmp_path / "no-store.json"))
    monkeypatch.setenv(ENV_ENV_FILE, str(tmp_path / "mural.default.env"))

    out = mural_module._tool_auth_status({})

    assert out["authenticated"] is False
    assert frozenset(out.keys()) == AUTH_STATUS_UNAUTHENTICATED_KEYS


def test_tool_auth_status_authenticated_contract(
    mural_module: Any,
    tmp_path: Any,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """`_tool_auth_status` returns authenticated keys with profile-scoped values."""
    from test_constants import ENV_ENV_FILE, ENV_TOKEN_STORE, TEST_CLIENT_ID

    store_path = tmp_path / "mural-token.json"
    store_path.write_text("{}")
    monkeypatch.setenv(ENV_TOKEN_STORE, str(store_path))
    monkeypatch.setenv(ENV_ENV_FILE, str(tmp_path / "mural.default.env"))
    monkeypatch.setattr(
        mural_module,
        "_load_token_store",
        lambda path: {
            "schema_version": 2,
            "profiles": {
                "default": {
                    "client_id": TEST_CLIENT_ID,
                    "access_token": "x",
                    "refresh_token": "y",
                    "token_type": "Bearer",
                    "obtained_at": 0,
                    "granted_scopes": ["murals:read"],
                    "expires_at": 9999,
                },
            },
        },
    )

    out = mural_module._tool_auth_status({})

    assert out["authenticated"] is True
    assert out["profile"] == "default"
    assert out["granted_scopes"] == ["murals:read"]
    assert out["expires_at"] == 9999
    assert out["has_refresh_token"] is True
    assert frozenset(out.keys()) == AUTH_STATUS_AUTHENTICATED_KEYS


def test_tool_auth_status_accepts_profile_argument(
    mural_module: Any,
    tmp_path: Any,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The MCP handler honors an explicit ``profile`` argument."""
    from test_constants import ENV_ENV_FILE, ENV_TOKEN_STORE, TEST_CLIENT_ID

    store_path = tmp_path / "mural-token.json"
    store_path.write_text("{}")
    monkeypatch.setenv(ENV_TOKEN_STORE, str(store_path))
    monkeypatch.setenv(ENV_ENV_FILE, str(tmp_path / "mural.alt.env"))
    monkeypatch.setattr(
        mural_module,
        "_load_token_store",
        lambda path: {
            "schema_version": 2,
            "active_profile": "default",
            "profiles": {
                "default": {
                    "client_id": TEST_CLIENT_ID,
                    "access_token": "a",
                    "refresh_token": "b",
                    "token_type": "Bearer",
                    "obtained_at": 0,
                    "granted_scopes": ["murals:read"],
                    "expires_at": 1,
                },
                "alt": {
                    "client_id": TEST_CLIENT_ID,
                    "access_token": "c",
                    "refresh_token": "d",
                    "token_type": "Bearer",
                    "obtained_at": 0,
                    "granted_scopes": ["murals:write"],
                    "expires_at": 2,
                },
            },
        },
    )

    out = mural_module._tool_auth_status({"profile": "alt"})

    assert out["authenticated"] is True
    assert out["profile"] == "alt"
    assert out["granted_scopes"] == ["murals:write"]
    assert out["expires_at"] == 2


def test_tool_auth_status_registry_advertises_profile_argument(
    mural_module: Any,
) -> None:
    """The tool registry exposes the new ``profile`` input and updated description."""
    spec = mural_module._TOOL_REGISTRY["mural_auth_status"]
    schema = spec["input_schema"]
    assert schema["type"] == "object"
    assert schema["additionalProperties"] is False
    assert "profile" in schema["properties"]
    assert schema["properties"]["profile"]["type"] == "string"
    assert "credential_file" in spec["description"]
    assert "credential_file_exists" in spec["description"]
    assert spec["annotations"]["readOnlyHint"] is True
