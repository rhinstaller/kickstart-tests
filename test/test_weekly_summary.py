#!/usr/bin/python3
#
# Unit tests for the artifact selection logic in scripts/weekly-summary
#
# Run with: pytest test/test_weekly_summary.py

import importlib.machinery
import importlib.util
import os
import sys

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "scripts", "weekly-summary")


def load_module():
    """Import scripts/weekly-summary, which has no .py extension"""
    spec = importlib.util.spec_from_loader(
        "weekly_summary", importlib.machinery.SourceFileLoader("weekly_summary", SCRIPT))
    mod = importlib.util.module_from_spec(spec)
    sys.modules["weekly_summary"] = mod
    spec.loader.exec_module(mod)
    return mod


ws = load_module()


def artifact(name, updated_at, run_id=1):
    return {"name": name, "updated_at": updated_at, "workflow_run": {"id": run_id}}


# --- dedupe_newest ------------------------------------------------------

def test_same_day_collision_keeps_the_newest():
    # weekly-summary names downloads <artifact>-<YYYY-MM-DD>.zip, so several
    # runs on one day collide. The last run of the day is the current state.
    arts = [
        artifact("logs-centos10", "2026-10-01T01:50:06Z", run_id=1),
        artifact("logs-centos10", "2026-10-01T16:06:48Z", run_id=2),
        artifact("logs-centos10", "2026-10-01T10:47:16Z", run_id=3),
    ]
    kept = ws.dedupe_newest(arts)
    assert [a["updated_at"] for a in kept] == ["2026-10-01T16:06:48Z"]


def test_different_days_are_both_kept():
    arts = [
        artifact("logs-rhel9", "2026-10-01T03:00:00Z"),
        artifact("logs-rhel9", "2026-10-02T03:00:00Z"),
    ]
    assert len(ws.dedupe_newest(arts)) == 2


def test_different_scenarios_same_day_are_both_kept():
    arts = [
        artifact("logs-rhel9", "2026-10-01T03:00:00Z"),
        artifact("logs-rhel10", "2026-10-01T04:00:00Z"),
    ]
    assert len(ws.dedupe_newest(arts)) == 2


def test_result_is_sorted_by_time():
    arts = [
        artifact("logs-rhel9", "2026-10-03T03:00:00Z"),
        artifact("logs-rhel9", "2026-10-01T03:00:00Z"),
        artifact("logs-rhel9", "2026-10-02T03:00:00Z"),
    ]
    kept = [a["updated_at"] for a in ws.dedupe_newest(arts)]
    assert kept == sorted(kept)


def test_dedupe_of_nothing_is_nothing():
    assert ws.dedupe_newest([]) == []


# --- filter_by_event ----------------------------------------------------

def test_keeps_only_the_requested_event():
    arts = [
        artifact("logs-rhel9", "2026-10-01T03:00:00Z", run_id=10),
        artifact("logs-rhel9", "2026-10-02T03:00:00Z", run_id=11),
    ]
    events = {10: "schedule", 11: "workflow_dispatch"}
    kept = ws.filter_by_event(arts, events, "schedule")
    assert [a["workflow_run"]["id"] for a in kept] == [10]


def test_pr_comment_runs_are_dropped_even_though_they_are_on_main():
    # test-os-variants runs from a PR comment report head_branch "main", so a
    # branch filter would not catch them; the event is what distinguishes them.
    arts = [artifact("logs-rhel9", "2026-10-01T03:00:00Z", run_id=20)]
    assert ws.filter_by_event(arts, {20: "issue_comment"}, "schedule") == []


def test_unknown_provenance_is_dropped():
    # If the run could not be resolved we do not know where the data came from
    arts = [artifact("logs-rhel9", "2026-10-01T03:00:00Z", run_id=30)]
    assert ws.filter_by_event(arts, {}, "schedule") == []


def test_no_event_filter_keeps_everything():
    arts = [
        artifact("logs-rhel9", "2026-10-01T03:00:00Z", run_id=10),
        artifact("logs-rhel9", "2026-10-02T03:00:00Z", run_id=11),
    ]
    events = {10: "schedule", 11: "workflow_dispatch"}
    assert ws.filter_by_event(arts, events, None) == arts


def test_artifact_without_a_workflow_run_is_dropped_when_filtering():
    arts = [{"name": "logs-rhel9", "updated_at": "2026-10-01T03:00:00Z"}]
    assert ws.filter_by_event(arts, {}, "schedule") == []
