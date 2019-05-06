# check root account is locked
%post --interpreter=/usr/bin/python3

errors = []

# Test that the root password is what we expect it to be
with open("/etc/shadow", "r") as f:
    for line in f:
        if line.startswith("root:"):
            shadow_fields = line.strip().split(":")
            break
    else:
        errors.append("Unable to find root password")

if shadow_fields[1][0] != "!":
    error.append("Root password is not locked: %s" % shadow_fields[1])

# write errors, if any, to RESULT file
if errors:
    with open("/root/RESULT", "wt") as result:
        for e in errors:
            result.write(e + "\n")
%end

