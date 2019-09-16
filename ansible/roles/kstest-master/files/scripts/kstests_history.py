#!/usr/bin/python3

import os
import sys
import re
from argparse import ArgumentParser

parser = ArgumentParser(description="""
Create summary html page from directory containing results of kickstart test runs.
""")

parser.add_argument("runs_directory", metavar="RUNS_DIRECTORY", type=str,
                    help="Directory containing kickstart test runs data")
parser.add_argument("--report_filename", "-r", metavar="REPORT_FILENAME", type=str,
                    default="result_report.txt", help="Name of the file with run result report")
parser.add_argument("--isomd5sum_filename", "-m", metavar="ISO_MD5_SUM_FILENAME", type=str,
                    default="isomd5sum.txt", help="Name of the file with md5 sum of boot iso")
parser.add_argument("--status_count", "-s", metavar="NUMBER_OF_LATEST_RESULTS", type=int,
                    default=3, help="Number of latest results to be used for status")

args = parser.parse_args()

results_path = args.runs_directory
report_filename = args.report_filename
md5sum_filename = args.isomd5sum_filename
history_length = args.status_count

params_filename = "test_parameters.txt"
TEST_TIME_RE = re.compile(r'TIME_OF_RUNNING_TESTS:\s([^\s]*)')

header_row = [" "]
tests = {}

history_data = {}
HISTORY_SUCCESS = 0
HISTORY_FAILED = 1
HISTORY_UNKNOWN = 2
HISTORY_NOT_RUN = 3

ANACONDA_VER_RE = re.compile(r'.*main:\s*/sbin/anaconda\s*(.*)')

results_dir = os.path.basename(results_path)

def get_anconda_ver(result_path):
    anaconda_log = os.path.join(result_path, "anaconda/anaconda.log")
    if os.path.exists(anaconda_log):
        with open(anaconda_log, "r") as flog:
            for line in flog:
                m = ANACONDA_VER_RE.match(line)
                if m:
                    return (m.groups(1)[0])

count = 0
old_isomd5 = ""
for result_dir in sorted(os.listdir(results_path)):
    result_path = os.path.join(results_path, result_dir)

    report_file = os.path.join(result_path, report_filename)
    if not os.path.exists(report_file):
        print("No {} found, skipping".format(report_file), file=sys.stderr)
        continue

    count = count + 1
    anaconda_ver = ""

    with open(report_file) as f:
        for test, results in tests.items():
            results.append(" ")
            history_data[test].append(HISTORY_NOT_RUN)
        state = "start"
        for line in f.readlines():
            if state == "start":
                if line.startswith("---------"):
                    state = "results"
                continue
            if state == "results":
                if not line.strip():
                    break
                detail = ""
                sline = line.split("|")
                test = sline[0].strip()
                result = sline[-2].strip()
                if result == "FAILED":
                    expl = sline[-1].strip()
                    if "does not exist" in expl:
                        detail = "NEXIST"
                    elif expl.endswith("FAILED:"):
                        detail = "EMPTY"
                    elif "Traceback" in expl:
                        detail = "TRACEBACK"
                    elif "Kernel panic" in expl:
                        detail = "PANIC"
                    elif "Call Trace" in expl:
                        detail = "CALL TRACE"
                    elif "Problem starting" in expl:
                        detail = "VIRT-INSTALL"
                    elif "Out of memory" in expl:
                        detail = "OOM"
                    elif "error in log" in expl:
                        detail = "ERROR IN LOG"

                if not test in tests:
                    tests[test] = [" "] * count
                    history_data[test] = [HISTORY_NOT_RUN] * (count - 1) + [HISTORY_UNKNOWN]
                ref = ""
                test_log_dirs = [d for d in os.listdir(result_path) if d.startswith("kstest-{}.".format(test))]
                if test_log_dirs:
                    ref = "{}/{}/{}".format(results_dir, result_dir, test_log_dirs[0])
                    if not anaconda_ver:
                        res_path = os.path.join(results_path, result_dir, test_log_dirs[0])
                        anaconda_ver = get_anconda_ver(res_path)
                tests[test].pop()
                if ref:
                    tests[test].append("<a href={}>{}</a> {}".format(ref, result, detail))
                else:
                    tests[test].append("{} {}".format(result, detail))

                if result == "SUCCESS":
                    history_data[test].pop()
                    history_data[test].append(HISTORY_SUCCESS)
                elif result == "FAILED" and not detail:
                    history_data[test].pop()
                    history_data[test].append(HISTORY_FAILED)
                else:
                    history_data[test].pop()
                    history_data[test].append(HISTORY_UNKNOWN)

    with open(os.path.join(result_path, md5sum_filename), "r") as f:
        isomd5 = f.read()
    header = "<a href=\"{}/{}\">{}</a></br>{}</br>{}".format(results_dir, result_dir, result_dir, anaconda_ver,
                                                             "[NEW ISO]" if isomd5 != old_isomd5 else "-")
    old_isomd5 = isomd5

    params_file = os.path.join(result_path, params_filename)
    if not os.path.isfile(params_file):
        print("Can't parse out test run time from {}: not found".format(params_file), file=sys.stderr)
    else:
        with open(params_file, "r") as f:
            match = TEST_TIME_RE.search(f.read())
            if match and match.groups():
                header += "</br>{}".format(match.groups()[0])
            else:
                print("Can't parse out test run time from {}: value not found".format(params_file), file=sys.stderr)

    header_row.append(header)

thead = """
<tr>
{}
<td>STATUS from last {} runs</td>
</tr>
""".format("\n".join(["<td>{}</td>".format(label) for label in header_row]), history_length)

rows = []
for test in sorted(tests):
    current_history = history_data[test][-history_length:]
    worth_looking_failed = HISTORY_FAILED in current_history
    worth_looking_no_success = HISTORY_SUCCESS not in current_history
    test_not_run = all(h == HISTORY_NOT_RUN for h in current_history)
    new_failed = HISTORY_FAILED not in current_history[:-1] \
        and current_history[-1] == HISTORY_FAILED
    cols = ["<td>{}</td>".format(result) for result in tests[test]]
    cols.insert(0, "<td>{}</td>".format(test))
    if test_not_run:
        cols.append("<td>{}</td>".format(test))
    elif new_failed:
        cols.append("<td bgcolor=\"#ff00dc\">{}</td>".format(test))
    elif worth_looking_failed:
        cols.append("<td bgcolor=\"#ff3e00\">{}</td>".format(test))
    elif worth_looking_no_success:
        cols.append("<td bgcolor=\"#ffc500\">{}</td>".format(test))
    else:
        cols.append("<td>{}</td>".format(test))
    row = "<tr>{}</tr>\n".format("".join(cols))
    rows.append(row)

tbody = "".join(rows)

page = """
<html>
<body>
<table>
<thead>
{}
</thead>
<tbody>
{}
</tbody>
</table>
</body>
</html>
""".format(thead, tbody)

print(page)
