#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

artifacts_dir="${1:?artifacts dir is required}"
release_version="${2:?release version is required}"
output_dir="${3:?output dir is required}"

mkdir -p "$output_dir"

strip_build_suffix() {
  printf '%s' "$1" | sed -E 's/-[0-9a-f]{7,12}-Release$//'
}

strip_build_suffix_from_file() {
  printf '%s' "$1" | sed -E 's/-[0-9a-f]{7,12}-Release//'
}

zip_dir_contents() {
  local source_dir="$1"
  local archive_path="$2"
  (
    cd "$source_dir"
    zip -r -9 "$archive_path" .
  )
}

for dir in "$artifacts_dir"/*; do
  [[ -d "$dir" ]] || continue
  artifact_name="$(basename "$dir")"

  case "$artifact_name" in
    ProjTLauncher-*-Qt6-Portable-*)
      base_name="$(strip_build_suffix "$artifact_name")"
      portable_tarball=("$dir"/ProjTLauncher-portable.tar.gz)
      if [[ -f "${portable_tarball[0]:-}" ]]; then
        cp "${portable_tarball[0]}" "$output_dir/${base_name}-${release_version}.tar.gz"
      fi
      ;;
    ProjTLauncher-*.AppImage)
      for file in "$dir"/*.AppImage; do
        target_name="$(strip_build_suffix_from_file "$(basename "$file")")"
        cp "$file" "$output_dir/$target_name"
      done
      ;;
    ProjTLauncher-*.AppImage.zsync)
      for file in "$dir"/*.zsync; do
        target_name="$(strip_build_suffix_from_file "$(basename "$file")")"
        cp "$file" "$output_dir/$target_name"
      done
      ;;
    ProjTLauncher-macOS-*)
      base_name="$(strip_build_suffix "$artifact_name")"
      for file in "$dir"/*; do
        [[ -f "$file" ]] || continue
        case "$(basename "$file")" in
          ProjTLauncher.zip)
            cp "$file" "$output_dir/${base_name}-${release_version}.zip"
            ;;
          ProjTLauncher.dmg)
            cp "$file" "$output_dir/${base_name}-${release_version}.dmg"
            ;;
          ProjTLauncher-macOS-*.pkg)
            cp "$file" "$output_dir/${base_name}-${release_version}.pkg"
            ;;
        esac
      done
      ;;
    ProjTLauncher-Windows-*)
      base_name="$(strip_build_suffix "$artifact_name")"
      exe_files=("$dir"/*.exe)
      if [[ "$artifact_name" == *"-Setup-"* ]] && [[ -f "${exe_files[0]:-}" ]]; then
        cp "${exe_files[0]}" "$output_dir/${base_name}.exe"
      else
        zip_dir_contents "$dir" "$PWD/$output_dir/${base_name}-${release_version}.zip"
      fi
      ;;
    cpack-*)
      for file in "$dir"/*; do
        [[ -f "$file" ]] || continue
        cp "$file" "$output_dir/$(basename "$file")"
      done
      ;;
  esac
done

if [[ -z "$(find "$output_dir" -mindepth 1 -print -quit)" ]]; then
  echo "No release artifacts were prepared from $artifacts_dir" >&2
  exit 1
fi
