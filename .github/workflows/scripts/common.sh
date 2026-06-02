#!/usr/bin/env bash

# gh_api_safe — wrapper around `gh api` that distinguishes 2xx success from
# transient/auth failures and never lets non-JSON error bodies poison downstream
# parsers (the failure class that caused #471 and #487).
#
# Usage:
#   if response=$(gh_api_safe "repos/${REPO}/branches/develop"); then
#     # response is guaranteed valid JSON; safe to pipe to jq
#     echo "$response" | jq -r '.commit.sha'
#   else
#     # exit code carries the class:
#     #   1 — 404 (resource absent; often expected, caller decides)
#     #   2 — 403 (auth / suspension; CI infra issue, raise loudly)
#     #   3 — other 4xx / 5xx (transient or schema; caller decides)
#     #   4 — non-JSON body despite 2xx (server error / proxy intercept)
#     case $? in
#       1) develop_exists=false ;;
#       2) echo "::error::Auth failure on $endpoint — see #487"; exit 1 ;;
#       3|4) echo "::warning::Unexpected response — degrading"; develop_exists=unknown ;;
#     esac
#   fi
gh_api_safe() {
  local endpoint=$1 ; shift
  local body_file headers_file
  body_file=$(mktemp)
  headers_file=$(mktemp)
  local status=0

  # `gh api -i` includes headers; -i + tee separates status line from body. We
  # avoid `gh api ... 2>&1` (which sources the #471 jq-crash class) by writing
  # stderr to a file and only consuming it on failure.
  if ! gh api -i "$endpoint" "$@" >"$body_file" 2>"$headers_file" ; then
    local stderr_text
    stderr_text=$(head -c 300 "$headers_file")
    # The stderr text from `gh api` is typically `gh: <HTTP status> <body excerpt>`.
    if [[ "$stderr_text" == *"404"* || "$stderr_text" == *"Not Found"* ]]; then
      status=1
    elif [[ "$stderr_text" == *"403"* || "$stderr_text" == *"suspended"* ]]; then
      status=2
    else
      status=3
    fi
    >&2 echo "::warning::gh api $endpoint failed: $stderr_text"
    rm -f "$body_file" "$headers_file"
    return "$status"
  fi

  # Strip HTTP headers (`HTTP/2 200`, `Server: GitHub.com`, …, blank line).
  local body
  body=$(awk 'started{print} /^\r?$/{started=1}' "$body_file")
  rm -f "$body_file" "$headers_file"

  # Verify JSON shape so caller can pipe to jq without checking.
  if [[ -z "$body" ]] || ! echo "$body" | jq empty >/dev/null 2>&1 ; then
    >&2 echo "::warning::gh api $endpoint returned non-JSON 2xx; body excerpt: $(head -c 200 <<<"$body")"
    return 4
  fi
  printf '%s\n' "$body"
}

sync_path_matches_prefix() {
  local candidate_path="$1"
  local prefix_path="$2"
  [[ "${candidate_path}" == "${prefix_path}" || "${candidate_path}" == "${prefix_path}/"* ]]
}

sync_resolve_target_path_from_rows() {
  local source_file_path="$1"
  local rows_text="$2"
  local source_path
  local target_path

  while IFS=$'\t' read -r source_path target_path _strategy _overlay_path _merge_spec; do
    [[ -n "${source_path}" ]] || continue
    if [[ "${source_file_path}" == "${source_path}" ]]; then
      printf '%s\n' "${target_path}"
      return 0
    fi
    if [[ "${source_file_path}" == "${source_path}/"* ]]; then
      local source_prefix="${source_path}/"
      printf '%s/%s\n' "${target_path}" "${source_file_path#"$source_prefix"}"
      return 0
    fi
  done <<< "${rows_text}"

  return 1
}

sync_resolve_target_path_from_prefixes() {
  local source_file_path="$1"
  local prefixes_text="$2"
  local sync_path

  while IFS= read -r sync_path; do
    [[ -n "${sync_path}" ]] || continue
    if sync_path_matches_prefix "${source_file_path}" "${sync_path}"; then
      printf '%s\n' "${source_file_path}"
      return 0
    fi
  done <<< "${prefixes_text}"

  return 1
}

sync_source_deleted_in_last_commit() {
  local source_path="$1"
  local deleted_paths_text="$2"
  local deleted_path

  while IFS= read -r deleted_path; do
    [[ -n "${deleted_path}" ]] || continue
    if [[ "${deleted_path}" == "${source_path}" || "${deleted_path}" == "${source_path}/"* ]]; then
      return 0
    fi
  done <<< "${deleted_paths_text}"

  return 1
}

sync_is_real_directory() {
  local path="$1"
  [[ -d "${path}" && ! -L "${path}" ]]
}

sync_target_path_is_compatible() {
  local source_path="$1"
  local target_path="$2"
  local repo_dir="$3"
  local target_fs_path="${repo_dir}/${target_path}"

  # shellcheck disable=SC2034
  SYNC_ERROR_MESSAGE=""

  if [[ -L "${target_fs_path}" ]]; then
    SYNC_ERROR_MESSAGE="target ${target_path} is a symlink; refusing to sync ${source_path}"
    return 1
  fi

  if [[ -d "${source_path}" ]]; then
    if [[ -e "${target_fs_path}" && ! -d "${target_fs_path}" ]]; then
      SYNC_ERROR_MESSAGE="target ${target_path} exists as a non-directory but source ${source_path} is a directory"
      return 1
    fi
  else
    if [[ -d "${target_fs_path}" ]]; then
      SYNC_ERROR_MESSAGE="target ${target_path} exists as a directory but source ${source_path} is a file"
      return 1
    fi
  fi

  return 0
}

sync_copy_source_to_target() {
  local source_path="$1"
  local target_path="$2"
  local repo_dir="$3"
  local target_fs_path="${repo_dir}/${target_path}"

  if [[ -d "${source_path}" ]]; then
    mkdir -p "${target_fs_path}"
    cp -R "${source_path}/." "${target_fs_path}/"
  else
    cp "${source_path}" "${target_fs_path}"
  fi
}

sync_delete_target_path() {
  local repo_dir="$1"
  local target_path="$2"
  local target_fs_path="${repo_dir}/${target_path}"

  # shellcheck disable=SC2034
  SYNC_ERROR_MESSAGE=""

  if sync_is_real_directory "${target_fs_path}"; then
    # shellcheck disable=SC2034
    SYNC_ERROR_MESSAGE="skip delete directory ${target_path}"
    return 2
  fi

  # Use git rm to properly stage the deletion for commit.
  # --ignore-unmatch: don't fail if file doesn't exist or isn't tracked.
  # -f: force removal even if file has local modifications.
  # Deletions are staged here; callers should only run git add for
  # copied/updated paths afterwards.
  git -C "${repo_dir}" rm -f --ignore-unmatch -- "${target_path}" >/dev/null 2>&1 || true
  # Always remove from disk: git rm --ignore-unmatch returns success but
  # does NOT delete untracked files from the working tree.
  rm -f "${target_fs_path}"
}

sync_cleanup_remote_branch() {
  local repo="$1"
  local branch="$2"
  local cleanup_output

  if ! cleanup_output=$(gh api -X DELETE "repos/${repo}/git/refs/heads/${branch}" 2>&1); then
    if [[ "${cleanup_output}" == *"Reference does not exist"* ]]; then
      printf 'SKIP remote branch %s already deleted\n' "${branch}"
      return 0
    fi

    printf 'FAIL delete remote branch %s\n' "${branch}"
    printf '%s\n' "${cleanup_output}" | sed 's/^/  /'
    return 1
  fi

  return 0
}

sync_push_has_relevant_changes_from_prefixes() {
  local changed_paths_text="$1"
  local prefixes_text="$2"
  local changed_path
  local sync_path

  while IFS= read -r changed_path; do
    [[ -n "${changed_path}" ]] || continue
    while IFS= read -r sync_path; do
      [[ -n "${sync_path}" ]] || continue
      if sync_path_matches_prefix "${changed_path}" "${sync_path}"; then
        return 0
      fi
    done <<< "${prefixes_text}"
  done <<< "${changed_paths_text}"

  return 1
}

sync_write_summary_lines() {
  local summary_file="$1"
  shift
  local line

  for line in "$@"; do
    printf '%s\n' "${line}"
  done >> "${summary_file}"
}

sync_log_path_list() {
  local label="$1"
  shift
  local path

  if [[ "$#" -eq 0 ]]; then
    printf '%s none\n' "${label}"
    return 0
  fi

  printf '%s\n' "${label}"
  for path in "$@"; do
    printf '  %s\n' "${path}"
  done
}

sync_reap_target_paths() {
  # Iterate `reap_paths_text` (newline-separated), deleting each path
  # under `repo_dir` if and only if it currently exists. Status lines go
  # to stderr (REAP / REAP-SKIP-MISSING / REAP-SKIP-DIR). Successfully
  # reaped paths are echoed on stdout, one per line, so callers can
  # capture them with `mapfile -t arr < <(sync_reap_target_paths ...)`
  # and feed them into the existing target_paths/DELETE_PATHS arrays.
  #
  # Used by the SoT-side stale-file reaper (#193 finding 2): the SoT
  # carried `auto-release.yml` before the release-please migration; once
  # removed from the SoT, the deletion signal was lost (the immediate-
  # push window only covers the most recent commit range). This helper
  # gives the workflow an explicit "delete these paths everywhere on
  # every run" lever, independent of source-side history.
  local repo_dir="$1"
  local reap_paths_text="$2"
  local reap_path
  local fs_path

  while IFS= read -r reap_path; do
    reap_path="$(printf '%s' "${reap_path}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [[ -n "${reap_path}" ]] || continue
    fs_path="${repo_dir}/${reap_path}"
    if [[ ! -e "${fs_path}" && ! -L "${fs_path}" ]]; then
      printf '  REAP-SKIP-MISSING %s\n' "${reap_path}" >&2
      continue
    fi
    if ! sync_delete_target_path "${repo_dir}" "${reap_path}" >/dev/null 2>&1; then
      # rc=2 = real directory; refuse silently so we never wipe a tree
      # by accident. Mirrors the existing source-deletion behaviour.
      printf '  REAP-SKIP-DIR %s\n' "${reap_path}" >&2
      continue
    fi
    printf '  REAP %s\n' "${reap_path}" >&2
    printf '%s\n' "${reap_path}"
  done <<< "${reap_paths_text}"

  return 0
}

sync_push_has_relevant_changes_from_rows() {
  local changed_paths_text="$1"
  local rows_text="$2"
  local changed_path
  local source_path
  local target_path

  while IFS= read -r changed_path; do
    [[ -n "${changed_path}" ]] || continue
    while IFS=$'\t' read -r source_path target_path _strategy _overlay_path _merge_spec; do
      [[ -n "${source_path}" ]] || continue
      if sync_path_matches_prefix "${changed_path}" "${source_path}"; then
        return 0
      fi
    done <<< "${rows_text}"
  done <<< "${changed_paths_text}"

  return 1
}
