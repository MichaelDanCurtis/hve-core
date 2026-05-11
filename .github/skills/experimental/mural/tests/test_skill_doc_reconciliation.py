# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
"""Reconciliation guard between shipped SKILL.md and ``_TOOL_REGISTRY``."""

from __future__ import annotations

import pathlib
from typing import Any

SKILL_MD_PATH = pathlib.Path(__file__).resolve().parent.parent / "SKILL.md"


def test_skill_md_matches_tool_registry(mural_module: Any) -> None:
    diffs = mural_module._validate_skill_md(SKILL_MD_PATH)

    assert diffs == [], "SKILL.md drifted from _TOOL_REGISTRY:\n" + "\n".join(diffs)


def test_parse_skill_tool_table_returns_expected_tools(mural_module: Any) -> None:
    text = SKILL_MD_PATH.read_text(encoding="utf-8")
    rows = mural_module._parse_skill_tool_table(text)

    names = {row["name"] for row in rows}
    assert names == set(mural_module._TOOL_REGISTRY.keys())
