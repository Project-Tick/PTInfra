#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

artifacts_dir="${1:?artifacts dir is required}"
release_version="${2:?release version is required}"
output_dir="${3:?output dir is required}"
source_dir="${4:-}"

mkdir -p "$output_dir"

sign_file() {
  local path="$1"
  if [[ -n "${GPG_PRIVATE_KEY:-}" ]]; then
    if [[ -z "${GPG_KEY_IMPORTED:-}" ]]; then
      export GNUPGHOME
      GNUPGHOME="$(mktemp -d)"
      chmod 700 "$GNUPGHOME"
      printf '%s' "$GPG_PRIVATE_KEY" | gpg --batch --yes --pinentry-mode loopback --import
      GPG_KEY_IMPORTED=1
    fi

    if [[ -n "${GPG_KEY_ID:-}" ]]; then
      gpg --batch --yes --armor --pinentry-mode loopback --default-key "${GPG_KEY_ID}" --output "${path}.asc" --detach-sign "${path}"
    else
      gpg --batch --yes --armor --pinentry-mode loopback --output "${path}.asc" --detach-sign "${path}"
    fi
  fi
}

write_sha256_files() {
  find . -maxdepth 1 -type f ! -name '*.sha256' | while IFS= read -r file; do
    clean_name="${file#./}"
    sha256sum "$clean_name" > "${clean_name}.sha256"
  done
}

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
      if [[ "$base_name" != "ProjTLauncher-macOS-universal" ]]; then
        continue
      fi
      for file in "$dir"/*; do
        [[ -f "$file" ]] || continue
        case "$(basename "$file")" in
          ProjTLauncher.zip)
            cp "$file" "$output_dir/ProjTLauncher-macOS-${release_version}.zip"
            ;;
          ProjTLauncher-Installer.zip)
            cp "$file" "$output_dir/ProjTLauncher-macOS-Installer-${release_version}.zip"
            ;;
          ProjTLauncher.dmg)
            cp "$file" "$output_dir/ProjTLauncher-macOS-${release_version}.dmg"
            ;;
          ProjTLauncher-macOS-*.pkg)
            cp "$file" "$output_dir/ProjTLauncher-macOS-${release_version}.pkg"
            ;;
        esac
      done
      ;;
    ProjTLauncher-Windows-*)
      base_name="$(strip_build_suffix "$artifact_name")"
      case "$base_name" in
        ProjTLauncher-Windows-MSVC|ProjTLauncher-Windows-MSVC-Portable|ProjTLauncher-Windows-MSVC-Setup|ProjTLauncher-Windows-MSVC-arm64|ProjTLauncher-Windows-MSVC-arm64-Portable|ProjTLauncher-Windows-MSVC-arm64-Setup|ProjTLauncher-Windows-MinGW-w64|ProjTLauncher-Windows-MinGW-w64-Portable|ProjTLauncher-Windows-MinGW-w64-Setup|ProjTLauncher-Windows-MinGW-arm64|ProjTLauncher-Windows-MinGW-arm64-Portable|ProjTLauncher-Windows-MinGW-arm64-Setup)
          ;;
        *)
          continue
          ;;
      esac
      exe_files=("$dir"/*.exe)
      if [[ "$artifact_name" == *"-Setup-"* ]] && [[ -f "${exe_files[0]:-}" ]]; then
        cp "${exe_files[0]}" "$output_dir/${base_name}-${release_version}.exe"
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

if [[ -n "$source_dir" && -d "$source_dir" ]]; then
  temp_source_root="$(mktemp -d)"
  release_source_dir="$temp_source_root/ProjTLauncher-${release_version}"
  mkdir -p "$release_source_dir"

  tar -C "$source_dir" --exclude='.git' --exclude='.github' -cf - . | tar -C "$release_source_dir" -xf -
  tar -C "$temp_source_root" --exclude='.git' -czf "$output_dir/ProjTLauncher-${release_version}.tar.gz" "ProjTLauncher-${release_version}"

  libs=(libnbtplusplus zlib quazip bzip2 launcherjava tomlplusplus libqrencode extra-cmake-modules cmark javacheck)
  for lib in "${libs[@]}"; do
    if [[ ! -d "$source_dir/$lib" ]]; then
      echo "::warning::Source library directory '$lib' was not found under $source_dir; skipping."
      continue
    fi

    base="$output_dir/${lib}-${release_version}"
    tar -C "$source_dir" -czf "${base}.tar.gz" "$lib"
    tar -C "$source_dir" -cJf "${base}.tar.xz" "$lib"
    (
      cd "$source_dir"
      zip -r "../$(basename "${base}.zip")" "$lib"
    )
    mv "$(dirname "$source_dir")/$(basename "${base}.zip")" "${base}.zip"

    sign_file "${base}.tar.gz"
    sign_file "${base}.tar.xz"
    sign_file "${base}.zip"
  done
fi

if [[ -z "$(find "$output_dir" -mindepth 1 -print -quit)" ]]; then
  echo "No release artifacts were prepared from $artifacts_dir" >&2
  exit 1
fi

(
  cd "$output_dir"
  write_sha256_files
)
