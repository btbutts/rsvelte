#!/bin/bash

set -e

# If post-checkout was triggered by a file
# checkout ($4 is $3 of the hook), skip
CALLING_HOOK=$(basename "$1")

if [ "${CALLING_HOOK}" = "post-checkout" ]; then
    if [ "$4" -eq 0 ]; then
        exit 0
    fi
    LAST_ACTION=$(git reflog -1 --pretty=format:%gs)
    case "${LAST_ACTION}" in
        *pull*|*rebase*|*fetch*) ;;

        # Local branch switch, exit cleanly
        *) exit 0 ;;
    esac
fi

# Bypass if running inside GitHub Actions
if [ "${GITHUB_ACTIONS}" = "true" ]; then
    printf '%s\n' "CI/CD Environment detected. Skipping submodule auto-update."
    exit 0
fi

printf '%s\n' "Checking for top-level submodule parity updates..."

# Handle uninitialized submodules
# submodules already populated are skipped
git submodule update --init --checkout --depth 1

# Find submodules with newly pinned upstream updates
SUBMODULE_UPDATES=()
while IFS= read -r submodule; do
    SUBMODULE_UPDATES+=("$submodule")
done < <(git submodule status | awk '/^\+/ {print $2}')

if [ ${#SUBMODULE_UPDATES[@]} -eq 0 ]; then
    printf '%s\n' "All top-level submodules are up to date."
    exit 0
else
    printf '%s\n' "Found ${#SUBMODULE_UPDATES[@]} submodule(s) with upstream updates:"
    for module in "${SUBMODULE_UPDATES[@]}"; do
        git submodule update --init --depth 1 "$module" || {
            printf '%s\n\n' "ERROR: Failed to update submodule ${module##*/}!"
        }
    done
fi

printf '%s\n' "Submodule updates complete!"
