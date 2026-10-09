#!/usr/bin/python3
#
# Unit tests for the data layer of scripts/plot-summary
#
# Run with: pytest test/test_plot_summary.py

import importlib.util
import json
import os
import sys

import pytest

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "scripts", "plot-summary")


def load_module():
    """Import scripts/plot-summary, which has no .py extension"""
    spec = importlib.util.spec_from_loader(
        "plot_summary", importlib.machinery.SourceFileLoader("plot_summary", SCRIPT))
    mod = importlib.util.module_from_spec(spec)
    sys.modules["plot_summary"] = mod
    spec.loader.exec_module(mod)
    return mod


ps = load_module()


def result_line(name, status, msg="test done", digest="dfd1cca6972a"):
    return f"INFO: RESULT:{name}:{digest}:{status}:{msg}"


def entry(name, status, msg="test done", elapsed=60.0, scenario="logs-rhel9"):
    """Build a single test entry the way log2json emits them"""
    return {
        "name": name,
        "scenario": scenario,
        "success": status == "SUCCESS",
        "result": result_line(name, status, msg),
        "logfile": f"/var/tmp/kstest-{name}.2026_09_28-17_30_25.wwdmjci1/virt-install.log",
        "start_time": 1790616625.0,
        "end_time": 1790616625.0 + elapsed,
        "elapsed_time": elapsed,
    }


def write_run(tmp_path, scenario, day, tests):
    """Write a <scenario>-<YYYY-MM-DD>.json file the way weekly-summary does"""
    path = tmp_path / f"{scenario}-{day}.json"
    path.write_text(json.dumps(tests))
    return str(path)


# --- parse_result -------------------------------------------------------

def test_parse_result_success():
    assert ps.parse_result(result_line("script-pre", "SUCCESS")) == ("SUCCESS", "test done")


def test_parse_result_failed_keeps_full_message():
    line = result_line("basic-ftp", "FAILED", "Test failed on line: 15:04:23,226 WARNING foo")
    status, msg = ps.parse_result(line)
    assert status == "FAILED"
    # The message itself contains colons and must not be truncated at the first one
    assert msg == "Test failed on line: 15:04:23,226 WARNING foo"


def test_parse_result_missing():
    # log2json emits this shape for tests that never produced a RESULT line
    line = "INFO: RESULT:driverdisk-disk-kargs:missing:MISSING:Missing test"
    assert ps.parse_result(line) == ("MISSING", "Missing test")


def test_parse_result_empty_message():
    # 101 failures in real data have an empty message
    assert ps.parse_result(result_line("foo", "FAILED", "")) == ("FAILED", "")


def test_parse_result_unparseable_does_not_crash():
    status, msg = ps.parse_result("something entirely unexpected")
    assert status == "UNKNOWN"
    assert msg == "something entirely unexpected"


# --- outcome classification --------------------------------------------

def test_timeout_is_split_out_of_failed(tmp_path):
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [
        entry("driverdisk", "FAILED", "Test timed out", elapsed=3606.0),
    ])
    df = ps.load_runs([run])
    assert list(df.outcome) == ["TIMEOUT"]


def test_retry_after_failure_is_a_flake(tmp_path):
    # Same test, same scenario, same day: failed once then passed
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [
        entry("packages-multilib", "FAILED", "Validation failed with return code 1"),
        entry("packages-multilib", "SUCCESS"),
    ])
    df = ps.load_runs([run])
    assert sorted(df.outcome) == ["FLAKE", "SUCCESS"]


def test_failure_with_no_retry_stays_failed(tmp_path):
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [
        entry("packages-multilib", "FAILED"),
    ])
    df = ps.load_runs([run])
    assert list(df.outcome) == ["FAILED"]


def test_flake_does_not_leak_across_scenarios(tmp_path):
    # The notebook computed `failed` over the whole concatenated frame, so a pass
    # in one scenario masked a genuine failure in another. It must not.
    runs = [
        write_run(tmp_path, "logs-rhel9", "2026-09-29",
                  [entry("nfs-repo", "FAILED", scenario="logs-rhel9")]),
        write_run(tmp_path, "logs-rhel10", "2026-09-29",
                  [entry("nfs-repo", "SUCCESS", scenario="logs-rhel10")]),
    ]
    df = ps.load_runs(runs)
    rhel9 = df[df.scenario == "logs-rhel9"]
    assert list(rhel9.outcome) == ["FAILED"]


def test_flake_does_not_leak_across_days(tmp_path):
    # A test that failed Monday and passed Tuesday failed on Monday.
    runs = [
        write_run(tmp_path, "logs-rhel9", "2026-09-29", [entry("nfs-repo", "FAILED")]),
        write_run(tmp_path, "logs-rhel9", "2026-09-30", [entry("nfs-repo", "SUCCESS")]),
    ]
    df = ps.load_runs(runs)
    monday = df[df.day == "2026-09-29"]
    assert list(monday.outcome) == ["FAILED"]


def missing_entry(name="gone"):
    return {"name": name, "scenario": "logs-rhel9", "success": False,
            "result": "INFO: RESULT:%s:missing:MISSING:Missing test" % name,
            "logfile": "", "start_time": 0.0, "end_time": 0.0, "elapsed_time": 0.0}


def test_missing_results_are_dropped(tmp_path):
    # A test that never ran, or never recorded a verdict, has no duration and
    # is not a failure. It is left to the text report rather than shown as a
    # zero-second result on the charts.
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [
        missing_entry(),
        entry("ran", "SUCCESS"),
    ])
    df = ps.load_runs([run])
    assert list(df.name) == ["ran"]


def test_missing_results_are_not_counted_as_failures(tmp_path):
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [
        missing_entry(),
        entry("ran", "SUCCESS"),
    ])
    assert ps.failure_rows(ps.load_runs([run])).empty


def test_nothing_but_missing_results_raises(tmp_path):
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [missing_entry()])
    with pytest.raises(ValueError, match="outcome"):
        ps.load_runs([run])


def test_a_run_of_only_missing_results_is_skipped(tmp_path):
    good = write_run(tmp_path, "logs-rhel9", "2026-09-29", [entry("ran", "SUCCESS")])
    gone = write_run(tmp_path, "logs-rhel10", "2026-09-29", [missing_entry()])
    df = ps.load_runs([good, gone])
    assert list(df.scenario) == ["logs-rhel9"]


# --- file / day handling ------------------------------------------------

def test_day_comes_from_filename(tmp_path):
    run = write_run(tmp_path, "logs-daily-iso-webui", "2026-10-01", [entry("foo", "SUCCESS")])
    df = ps.load_runs([run])
    assert list(df.day) == ["2026-10-01"]
    # scenario comes from the file contents, not the (hyphen-laden) filename
    assert list(df.scenario) == ["logs-rhel9"]


def test_file_without_a_date_suffix_is_rejected(tmp_path):
    path = tmp_path / "kstest.log.json"
    path.write_text(json.dumps([entry("foo", "SUCCESS")]))
    with pytest.raises(ValueError, match="date"):
        ps.load_runs([str(path)])


def test_empty_run_file_is_skipped(tmp_path):
    good = write_run(tmp_path, "logs-rhel9", "2026-09-29", [entry("foo", "SUCCESS")])
    empty = write_run(tmp_path, "logs-rhel10", "2026-09-29", [])
    df = ps.load_runs([good, empty])
    assert len(df) == 1


def test_no_input_files_raises():
    with pytest.raises(ValueError, match="[Nn]o "):
        ps.load_runs([])


# --- failures table -----------------------------------------------------

def test_failure_rows_exclude_successes(tmp_path):
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [
        entry("a", "SUCCESS"),
        entry("b", "FAILED", "boom"),
        entry("c", "FAILED", "Test timed out"),
        entry("d", "FAILED"),
        entry("d", "SUCCESS"),
    ])
    rows = ps.failure_rows(ps.load_runs([run]))
    assert sorted(rows.name) == ["b", "c", "d"]
    assert sorted(rows.outcome) == ["FAILED", "FLAKE", "TIMEOUT"]


def test_failure_rows_carry_the_message(tmp_path):
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [entry("b", "FAILED", "boom")])
    rows = ps.failure_rows(ps.load_runs([run]))
    assert list(rows.message) == ["boom"]


def test_page_escapes_text_taken_from_the_logs(tmp_path):
    # Failure messages and test names come out of the test logs, so they reach
    # the page unvetted and have to be escaped.
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [
        entry("boom", "FAILED", "<script>alert('x')</script> & <b>bold</b>"),
    ])
    df = ps.load_runs([run])
    page = ps.render_page(df, "a & b <report>")

    assert "<script>alert" not in page
    assert "&lt;script&gt;alert" in page
    assert "&amp; &lt;b&gt;bold" in page
    # the report is inlined too, and is just as untrusted
    assert "a &amp; b &lt;report&gt;" in page
    # the page's own script block must survive escaping
    assert "addEventListener" in page


def test_page_renders_a_row_per_failure(tmp_path):
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [
        entry("a", "SUCCESS"),
        entry("b", "FAILED", "boom"),
        entry("c", "FAILED", "Test timed out"),
    ])
    page = ps.render_page(ps.load_runs([run]), "")
    assert page.count('<span class="pill') == 2
    assert "2 of 2 rows" not in page        # the count span is filled in by JS
    assert "of 2 rows" in page


def test_failure_rows_sorted_worst_first(tmp_path):
    run = write_run(tmp_path, "logs-rhel9", "2026-09-29", [
        entry("a", "FAILED", "Test timed out"),
        entry("b", "FAILED"),
        entry("c", "FAILED"),
        entry("c", "SUCCESS"),
    ])
    rows = ps.failure_rows(ps.load_runs([run]))
    # FAILED before TIMEOUT before FLAKE
    assert list(rows.outcome) == ["FAILED", "TIMEOUT", "FLAKE"]
