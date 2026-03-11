#!/usr/bin/env bash

set -euo pipefail

artifact_root="${1:?artifact root is required}"
remote_host="${2:?remote host is required}"
remote_user="${3:?remote user is required}"
remote_path="${4:?remote path is required}"
ssh_port="${5:-22}"

if [[ -z "$(find "$artifact_root" -mindepth 1 -print -quit)" ]]; then
  echo "No files found under $artifact_root" >&2
  exit 1
fi

rsync -av --delete \
  -e "ssh -p $ssh_port -o StrictHostKeyChecking=yes" \
  "$artifact_root"/ \
  "$remote_user@$remote_host:$remote_path/"
