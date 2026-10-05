#!/bin/bash
#
# Choose a payload mirror, and keep choosing the same one while it works.
#
# Mirrors come from MirrorManager rather than being written down in this repo,
# so one being retired needs no edit. Each platform says which repo to ask
# about, next to the variable it feeds:
#
#   export MIRROR_REPO_KSTEST_URL='rawhide'
#   export MIRROR_FALLBACKS_KSTEST_URL='https://dl.fedoraproject.org/...'
#
# If the variable already holds a mirror, it is checked and kept if it still
# works, which is what keeps the choice stable - and stability is the point,
# because the caching proxy in front of the test runners keys on URL, so a
# mirror that changes between runs is a cache that is always cold. Callers are
# expected to remember the previous answer: see the mirror selection step in
# .github/workflows/scenarios-permian.yml, which keeps it outside the
# workspace so it survives the cleanup between runs.
#
# This does not look for the fastest mirror. Deciding that needs a sustained
# transfer of a few hundred MB per candidate - latency and small files do not
# predict it, and have rated a 0.7 MB/s mirror level with a 37 MB/s one here.
# MirrorManager's ordering is proximity-weighted and is used as given.
#
# Writes shell code to stdout, and nothing at all when the current choice is
# still good.

MIRRORLIST_URL=${MIRRORLIST_URL:-http://mirrors.fedoraproject.org/mirrorlist}

# Seconds per mirror, and how many to try: on a bad day we walk a list, and it
# should fail in a couple of minutes rather than tens of them.
MIRROR_CHECK_TIMEOUT=${MIRROR_CHECK_TIMEOUT:-8}
MIRROR_CHECK_MAX=${MIRROR_CHECK_MAX:-8}

# Usable means it serves the repo metadata without redirecting us elsewhere. A
# redirect counts as failure on purpose: they lead to https, which the cache
# cannot store, and avoiding that is the whole point.
mirror_ok() {
    local out code redirect

    out=$(curl -sS -o /dev/null -r 0-1023 -m "${MIRROR_CHECK_TIMEOUT}" \
              -w '%{http_code} %{redirect_url}' \
              "${1}repodata/repomd.xml" 2>/dev/null) || return 1

    code="${out%% *}"
    redirect="${out#* }"

    [[ -n "${redirect}" ]] && return 1
    # 206 because we only ask for the first kilobyte.
    [[ "${code}" == "200" || "${code}" == "206" ]]
}

# $1 - name of the KSTEST_ variable holding the mirror to use
choose_mirror() {
    local var="$1"
    local current="${!var}"
    local repo="MIRROR_REPO_${var}"
    local fallbacks="MIRROR_FALLBACKS_${var}"
    local candidate

    # Empty on the first run on a host, or when no mirror is written down.
    if [[ -n "${current}" ]]; then
        mirror_ok "${current}" && return 0
        echo "WARNING: ${var} mirror ${current} is not usable" >&2
    fi

    # Everything is rewritten to plain http before being tried, because the
    # advertised protocol understates what mirrors serve - several listed as
    # https answer http just as well, and only those can be cached.
    for candidate in $(curl -sS -m "${MIRROR_CHECK_TIMEOUT}" \
                            "${MIRRORLIST_URL}?repo=${!repo}&arch=x86_64" 2>/dev/null \
                       | sed -n 's#^https\?://#http://#p' \
                       | head -n "${MIRROR_CHECK_MAX}") \
                     ${!fallbacks}; do
        [[ "${candidate}" == "${current}" ]] && continue
        if mirror_ok "${candidate}"; then
            echo "${var} set to ${candidate}" >&2
            echo "export ${var}='${candidate}'"
            return 0
        fi
    done

    # Leave whatever was there and let the tests fail against it: a known URL
    # that is down reads better than whichever mirror we happened to try last.
    echo "WARNING: no usable mirror found for ${var}, leaving it at '${current}'" >&2
}

# FTP mirrors are deliberately not checked. The tests using them are disabled
# (INSTALLER-4942) and, with outbound 21/tcp blocked, every probe would time
# out and walk the whole list on every run.
while IFS='=' read -r key _; do
    [[ "${key}" =~ ^MIRROR_REPO_ ]] || continue
    choose_mirror "${key#MIRROR_REPO_}"
done < <(printenv)

# The loop ends on a failed read, which would otherwise be this script's exit
# status whenever there was nothing to choose - and callers are entitled to
# treat a non-zero exit as "the selector could not run".
exit 0
