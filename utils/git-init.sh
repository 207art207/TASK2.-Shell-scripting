#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || exit 1
CONFIG_FILE="$SCRIPT_DIR/.configs/git-myconfig"

usage() {
    echo "Usage (run from the directory containing your projects):"
    echo "  $0                     - load settings and show help"
    echo "  $0 <dir>               - initialize a repository"
    echo "  $0 <dir> <remote-url>  - also add a remote"
    echo
    printf 'Configuration file: %s\n' "$CONFIG_FILE"
}

git_repo_check() {
    local dir="$1"
    git -C "$dir" rev-parse --git-dir >/dev/null 2>&1
}

empty_dir_check() {
    local dir="$1"
    local contents

    [[ -d "$dir" ]] || return 1
    contents=$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit) || return 1
    [[ -z "$contents" ]]
}

check_args_count() {
    if (( $# > 2 )); then
        echo "[error]Invalid number of parameters ($#); only 0, 1, or 2 are allowed." >&2
        usage
        exit 1
    fi
}

create_config() {
    local answer
    local user_name
    local user_email
    local user_branch

    printf "Configuration file '%s' was not found.\n" "$CONFIG_FILE"
    read -r -p "Create it now? [y/N]: " answer || exit 1

    case "$answer" in
        y|Y) ;;
        *)
            echo "Configuration was not created."
            exit 0
            ;;
    esac

    while :; do
        read -r -p "Git user.name: " user_name || exit 1

        if [[ -n "$user_name" ]]; then
            break
        fi

        echo "[error]user.name must not be empty." >&2
    done

    while :; do
        read -r -p "Git user.email: " user_email || exit 1

        if [[ -n "$user_email" ]]; then
            break
        fi

        echo "[error]user.email must not be empty." >&2
    done

    read -r -p "Default branch [main]: " user_branch || exit 1
    user_branch="${user_branch:-main}"

    if ! git check-ref-format --branch "$user_branch" >/dev/null 2>&1; then
        echo "[error]Invalid branch name: '$user_branch'." >&2
        exit 1
    fi

    mkdir -p -- "$SCRIPT_DIR/.configs" || exit 1

    (
        umask 077
        printf 'USER_NAME=%q\nUSER_EMAIL=%q\nUSER_BRANCH=%q\n' \
            "$user_name" "$user_email" "$user_branch" > "$CONFIG_FILE"
    ) || exit 1

    echo "Configuration saved to '$CONFIG_FILE'."
}

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        create_config
    fi

    source "$CONFIG_FILE" || exit 1

    if [[ -z "${USER_NAME:-}" ||
          -z "${USER_EMAIL:-}" ||
          -z "${USER_BRANCH:-}" ]]; then
        echo "[error]Configuration must define USER_NAME, USER_EMAIL and USER_BRANCH." >&2
        exit 1
    fi

    if ! git check-ref-format --branch "$USER_BRANCH" >/dev/null 2>&1; then
        echo "[error]Invalid USER_BRANCH in '$CONFIG_FILE': '$USER_BRANCH'." >&2
        exit 1
    fi
}

check_args_count "$@"

if ! command -v git >/dev/null; then
    echo "[error]Git is not installed." >&2
    exit 1
fi

if git_repo_check "."; then
    echo "[error]Run this script outside a Git repository." >&2
    exit 1
fi

load_config

if (( $# == 0 )); then
    usage

elif (( $# == 1 )); then
    case "$1" in
        ""|.|..|*/*)
            echo "[error] Specify a directory name, not a path." >&2
            exit 1
            ;;
    esac

    dir="./$1"

    if [[ -d "$dir" ]]; then
        if git_repo_check "$dir"; then
            echo "[error] Directory '$dir' already contains a Git repository." >&2
            exit 1
        fi

        if ! empty_dir_check "$dir"; then
            echo "[error] Directory '$dir' is not empty or cannot be read." >&2
            exit 1
        fi
    else
        mkdir -- "$dir" || exit 1
    fi

    git init -b "$USER_BRANCH" -- "$dir" || exit 1
    git -C "$dir" config --local user.name "$USER_NAME" || exit 1
    git -C "$dir" config --local user.email "$USER_EMAIL" || exit 1
    git -C "$dir" config --local init.defaultBranch "$USER_BRANCH" || exit 1

    printf '# %s\n' "$1" > "$dir/README.md" || exit 1

    echo "Repository initialized: $dir"

elif (( $# == 2 )); then
    case "$1" in
        ""|.|..|*/*)
            echo "[error] Specify a directory name, not a path." >&2
            exit 1
            ;;
    esac

    if [[ -z "$2" ]]; then
        echo "[error] Remote URL must not be empty." >&2
        exit 1
    fi

    dir="./$1"

    if [[ -d "$dir" ]]; then
        if git_repo_check "$dir"; then
            git -C "$dir" remote add origin "$2" || exit 1
            echo "Remote origin added to: $dir"
            exit 0
        fi

        if ! empty_dir_check "$dir"; then
            echo "[error] Directory '$dir' is not empty or cannot be read." >&2
            exit 1
        fi
    else
        mkdir -- "$dir" || exit 1
    fi

    git init -b "$USER_BRANCH" -- "$dir" || exit 1
    git -C "$dir" config --local user.name "$USER_NAME" || exit 1
    git -C "$dir" config --local user.email "$USER_EMAIL" || exit 1
    git -C "$dir" config --local init.defaultBranch "$USER_BRANCH" || exit 1

    printf '# %s\n' "$1" > "$dir/README.md" || exit 1

    git -C "$dir" remote add origin "$2" || exit 1

    echo "Repository initialized with remote origin: $dir"
fi