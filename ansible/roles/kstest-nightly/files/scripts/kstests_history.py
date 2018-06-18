#!/usr/bin/python3

import os
import sys


if len(sys.argv) < 4:
    print("usage: {} PATH_TO_RESULTS REPORT_FILENAME ISOMD5SUM_FILENAME".format(sys.argv[0]))
    exit(1)
else:
    RESULTS_PATH = sys.argv[1]
    REPORT_FILENAME = sys.argv[2]
    MD5SUM_FILENAME = sys.argv[3]

header_row = [" "]
tests = {}

RESULTS_DIR=os.path.basename(RESULTS_PATH)

count = 0
old_isomd5 = ""
for result_dir in sorted(os.listdir(RESULTS_PATH)):
    count = count + 1
    result_path = os.path.join(RESULTS_PATH, result_dir)

    report_file = os.path.join(result_path, REPORT_FILENAME)
    if not os.path.exists(report_file):
        print("No {} found, skipping".format(report_file), file=sys.stderr)
        continue

    with open(os.path.join(result_path, MD5SUM_FILENAME), "r") as f:
        isomd5 = f.read()
    header_row.append("<a href=\"{}/{}\">{}</a></br>{}".format(RESULTS_DIR, result_dir, result_dir, "[NEW ISO]" if isomd5 != old_isomd5 else "-"))
    old_isomd5 = isomd5

    with open(report_file) as f:
        for test, results in tests.items():
            results.append(" ")
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
                result = sline[1].strip()
                if result == "FAILED":
                    expl = sline[2].strip()
                    if "does not exist" in expl:
                        detail = "NEXIST"
                    elif expl.endswith("FAILED:"):
                        detail = "EMPTY"
                    elif "Traceback" in expl:
                        detail = "TRACEBACK"

                if not test in tests:
                    tests[test] = [" "] * count

                ref = ""
                test_log_dirs = [d for d in os.listdir(result_path) if d.startswith("kstest-{}".format(test))]
                if test_log_dirs:
                    ref = "{}/{}/{}".format(RESULTS_DIR, result_dir, test_log_dirs[0])
                tests[test].pop()
                tests[test].append("<a href={}>{}</a> {}".format(ref, result, detail))

thead = """
<tr>
{}
</tr>
""".format("\n".join(["<td>{}</td>".format(label) for label in header_row]))

rows = []
for test in sorted(tests):
    cols = ["<td>{}</td>".format(result) for result in tests[test]]
    cols.insert(0, "<td>{}</td>".format(test))
    row = "<tr>{}</tr>".format("".join(cols))
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
