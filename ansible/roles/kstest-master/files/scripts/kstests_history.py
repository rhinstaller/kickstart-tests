#!/usr/bin/python3

import os
import sys
import re
from argparse import ArgumentParser
from configparser import ConfigParser

dnf_available = True
try:
    import dnf.subject
    import hawkey
except ImportError:
    dnf_available = False

parser = ArgumentParser(description="""
Create summary html page from directory containing results of kickstart test runs.
""")

parser.add_argument("runs_directory", metavar="RUNS_DIRECTORY", type=str,
                    help="Directory containing kickstart test runs data")
parser.add_argument("--report_filename", "-r", metavar="REPORT_FILENAME", type=str,
                    default="result_report.txt", help="Name of the file with run result report")
parser.add_argument("--isomd5sum_filename", "-m", metavar="ISO_MD5_SUM_FILENAME", type=str,
                    default="isomd5sum.txt", help="Name of the file with md5 sum of boot iso")
parser.add_argument("--packages_filename", "-p", metavar="PACKAGES_FILENAME", type=str,
                    default="lorax-packages.log", help="Name of the file with installer image packages list")
parser.add_argument("--status_count", "-s", metavar="NUMBER_OF_LATEST_RESULTS", type=int,
                    default=3, help="Number of latest results to be used for status")

args = parser.parse_args()

results_path = args.runs_directory
report_filename = args.report_filename
md5sum_filename = args.isomd5sum_filename
packages_filename = args.packages_filename
history_length = args.status_count

params_filename = "test_parameters.txt"
TEST_TIME_RE = re.compile(r'TIME_OF_RUNNING_TESTS:\s([^\s]*)')

header_row = [" "]
package_diff_infos = []
tests = {}

history_data = {}
HISTORY_SUCCESS = 0
HISTORY_FAILED = 1
HISTORY_UNKNOWN = 2
HISTORY_NOT_RUN = 3

COLOR_NEW_FAILED = "#ff00dc"
COLOR_NO_SUCCESS = "#ffc500"
COLOR_SOME_FAILED = "#ff3e00"

ANACONDA_VERSION_IN_ANACONDA_LOG_RE = re.compile(r'.*main:\s*/sbin/anaconda\s*(.*)')

results_dir = os.path.basename(results_path)


class ImageRpms():
    def __init__(self, file_path):
        self._file_path = file_path
        self._rpms = {}
        pass

    @property
    def rpms(self):
        if not self._rpms:
            self._read_rpms(self._file_path)
        return self._rpms

    def _read_rpms(self, file_path):
        with open(file_path, "r") as f:
            for line in f:
                subject = dnf.subject.Subject(line.strip())
                nevra_possibilities = subject.get_nevra_possibilities(forms=[hawkey.FORM_NEVRA,
                                                                             hawkey.FORM_NEVR])
                if nevra_possibilities:
                    nevra = nevra_possibilities[0]
                    self._rpms[nevra.name] = "{}-{}".format(nevra.version, nevra.release)
                else:
                    print("Can't get nevra from line {}".format(line), file=sys.stderr)

    def added(self, image_rpms):
        return [p for p in self.rpms if p not in image_rpms.rpms]

    def removed(self, image_rpms):
        return [p for p in image_rpms.rpms if p not in self.rpms]

    def changed(self, image_rpms):
        return [p for p in self.rpms
                if p in image_rpms.rpms and self.rpms[p] != image_rpms.rpms[p]]


def get_anconda_version_from_log(result_path):
    anaconda_log = os.path.join(result_path, "anaconda/anaconda.log")
    if os.path.exists(anaconda_log):
        with open(anaconda_log, "r") as flog:
            for line in flog:
                m = ANACONDA_VERSION_IN_ANACONDA_LOG_RE.match(line)
                if m:
                    return (m.groups(1)[0])
    return ""


def get_params_from_file(filename):
    config = ConfigParser()
    if not os.path.isfile(filename):
        print("Can't get test parameters from {}: not found".format(params_file), file=sys.stderr)
        config.read_string("[top]\n")
    else:
        with open(filename) as stream:
            config.read_string("[top]\n" + stream.read())
    return config['top']


count = 0
isomd5 = ""
updates_img = ""
packages_file_path = ""
for result_dir in sorted(os.listdir(results_path)):
    result_path = os.path.join(results_path, result_dir)

    report_file = os.path.join(result_path, report_filename)
    if not os.path.exists(report_file):
        print("No {} found, skipping".format(report_file), file=sys.stderr)
        continue

    count = count + 1

    params_file = os.path.join(result_path, params_filename)
    params = get_params_from_file(params_file)

    anaconda_ver = params.get('ANACONDA_VERSION') or ""

    previous_packages_file_path = packages_file_path
    packages_file_path = os.path.join(result_path, packages_filename)

    previous_isomd5 = isomd5
    with open(os.path.join(result_path, md5sum_filename), "r") as f:
        isomd5 = f.read()
    new_iso = previous_isomd5 != isomd5

    previous_updates_img = updates_img
    updates_img = params.get('UPDATES_IMAGE') or ""

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
                        anaconda_ver = get_anconda_version_from_log(res_path)
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

    if updates_img:
        anaconda_ver = "{} +&nbsp;updates{}".format(
            anaconda_ver,
            "&nbsp;(NEW)" if updates_img != previous_updates_img else "",
        )

    header = "<a href=\"{}/{}\">{}</a></br>{}</br>{}".format(results_dir, result_dir, result_dir, anaconda_ver,
                                                             "[NEW ISO]" if new_iso else "-")


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

    file_ref = "<a href=\"{}/{}/{}\">{}</a> diff:</br>".format(results_dir, result_dir, packages_filename, packages_filename)
    if new_iso:
        if os.path.exists(packages_file_path) and os.path.exists(previous_packages_file_path):
            if dnf_available:
                rpms = ImageRpms(packages_file_path)
                previous_rpms = ImageRpms(previous_packages_file_path)
                changed = "</br>".join(p for p in rpms.changed(previous_rpms))
                added = "".join("</br>+{}".format(p) for p in rpms.added(previous_rpms))
                removed = "".join("</br>-{}".format(p) for p in rpms.removed(previous_rpms))
                package_diff_infos.append("{}{}{}{}".format(file_ref, changed, added, removed))
            else:
                package_diff_infos.append("{}N/A - missing dnf or hawkey module".format(file_ref))
        else:
            package_diff_infos.append("{}N/A".format(file_ref))
    else:
        package_diff_infos.append("{}".format(file_ref))

thead = """

<tr valign=\"top\">
{}
<td>
STATUS from last {} runs
</br><span style=\"background-color:{};\">new FAILED</span>
</br><span style=\"background-color:{};\">some FAILED</span>
</br><span style=\"background-color:{};\">no SUCCESS</span>
</td>
</tr>
""".format(
    "\n".join(["<td>{}</td>".format(label) for label in header_row]),
    history_length,
    COLOR_NEW_FAILED,
    COLOR_SOME_FAILED,
    COLOR_NO_SUCCESS
)

rows = []
for test in sorted(tests):

    current_history = history_data[test][-history_length:]
    worth_looking_failed = HISTORY_FAILED in current_history
    worth_looking_no_success = HISTORY_SUCCESS not in current_history
    test_not_run = all(h == HISTORY_NOT_RUN for h in current_history)
    new_failed = HISTORY_FAILED not in current_history[:-1] \
        and current_history[-1] == HISTORY_FAILED

    # Append row with the test results
    cols = ["<td>{}</td>".format(result) for result in tests[test]]
    cols.insert(0, "<td>{}</td>".format(test))
    if test_not_run:
        cols.append("<td>{}</td>".format(test))
    elif new_failed:
        cols.append("<td bgcolor=\"{}\">{}</td>".format(COLOR_NEW_FAILED, test))
    elif worth_looking_failed:
        cols.append("<td bgcolor=\"{}\">{}</td>".format(COLOR_SOME_FAILED, test))
    elif worth_looking_no_success:
        cols.append("<td bgcolor=\"{}\">{}</td>".format(COLOR_NO_SUCCESS, test))
    else:
        cols.append("<td>{}</td>".format(test))
    row = "<tr>{}</tr>\n".format("".join(cols))
    rows.append(row)

# Append row with package diffs
package_diff_cols = ["<td>{}</td>".format(diff_info) for diff_info in package_diff_infos]
package_diff_label_col = "<td>{}</td>".format("PACKAGE_DIFF")
package_diff_cols.insert(0, package_diff_label_col)
package_diff_cols.append(package_diff_label_col)
package_diff_row = "<tr valign=\"top\">{}</tr>\n".format("".join(package_diff_cols))
rows.append(package_diff_row)


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
