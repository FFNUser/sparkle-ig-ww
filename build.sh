#!/usr/bin/env bash

set -e

CMAKE_OSX_ARCHITECTURES="arm64e;arm64"
CMAKE_OSX_SYSROOT="iphoneos"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Sparkle version, read from the control file (single source of truth).
SPARKLE_VERSION="$(awk '/^Version:/ {print $2; exit}' "$ROOT_DIR/control")"

FFMPEG_MODULES_DIR="$ROOT_DIR/modules/ffmpegkit"
FFMPEG_FRAMEWORKS=(
    "$FFMPEG_MODULES_DIR/ffmpegkit.framework"
    "$FFMPEG_MODULES_DIR/libavcodec.framework"
    "$FFMPEG_MODULES_DIR/libavdevice.framework"
    "$FFMPEG_MODULES_DIR/libavfilter.framework"
    "$FFMPEG_MODULES_DIR/libavformat.framework"
    "$FFMPEG_MODULES_DIR/libavutil.framework"
    "$FFMPEG_MODULES_DIR/libswresample.framework"
    "$FFMPEG_MODULES_DIR/libswscale.framework"
)

ensure_ffmpeg_frameworks() {
    for framework in "${FFMPEG_FRAMEWORKS[@]}"; do
        if [ ! -d "$framework" ]; then
            echo -e "\033[1m\033[0;31mMissing FFmpeg framework: $framework\033[0m"
            echo "Run ./fetch-ffmpegkit.sh first."
            exit 1
        fi
    done
}

ensure_flexing_submodule() {
    if [ -z "$(ls -A "$ROOT_DIR/modules/FLEXing" 2>/dev/null)" ]; then
        echo -e '\033[1m\033[0;31mFLEXing submodule not found.\nPlease run the following command to checkout submodules:\n\n\033[0m    git submodule update --init --recursive'
        exit 1
    fi
}

build_flex_library() {
    echo -e '\033[1m\033[32mBuilding libFLEX.dylib...\033[0m'
    make -C "$ROOT_DIR/modules/FLEXing/libflex" clean
    make -C "$ROOT_DIR/modules/FLEXing/libflex" DEBUG=0 FINALPACKAGE=1
}

build_sideload_fix_library() {
    echo -e '\033[1m\033[32mBuilding SPKSideloadFix.dylib...\033[0m'
    make -C "$ROOT_DIR/modules/SPKSideloadFix" DEBUG=0 FINALPACKAGE=1
}

theos_dylib_path() {
    local name
    local path
    for name in "$@"; do
        for path in \
            ".theos/obj/${name}.dylib" \
            ".theos/obj/debug/${name}.dylib" \
            "modules/FLEXing/libflex/.theos/obj/${name}.dylib" \
            "modules/FLEXing/libflex/.theos/obj/debug/${name}.dylib"; do
            if [ -f "$ROOT_DIR/$path" ]; then
                echo "$ROOT_DIR/$path"
                return 0
            fi
        done
    done
    return 1
}

sideload_fix_dylib_path() {
    local path
    for path in \
        "$ROOT_DIR/modules/SPKSideloadFix/.theos/obj/SPKSideloadFix.dylib" \
        "$ROOT_DIR/modules/SPKSideloadFix/.theos/obj/debug/SPKSideloadFix.dylib"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

# Rename the freshly built .deb to Sparkle_v<version>_<rootless|rootful>.deb.
rename_sparkle_deb() {
    local scheme="$1"
    local newest dest
    newest="$(ls -t "$ROOT_DIR/packages/"com.sparkle.sparkle_*.deb 2>/dev/null | head -n 1)"
    if [ -z "$newest" ]; then
        echo -e '\033[1m\033[0;31mCould not find a built .deb to rename.\033[0m' >&2
        return 1
    fi
    dest="$ROOT_DIR/packages/Sparkle_v${SPARKLE_VERSION}_${scheme}.deb"
    mv -f "$newest" "$dest"
    echo "$dest"
}

sparkle_flag_token() {
    local parts=()
    if [ "${OPT_INJECT:-0}" -eq 1 ] && [ "${OPT_FFMPEG:-0}" -eq 1 ] && [ "${OPT_PATCH:-0}" -eq 1 ]; then
        [ "${OPT_DEV:-0}" -eq 1 ] && parts+=(dev)
        [ "${OPT_FLEX:-0}" -eq 0 ] && parts+=(no-flex)
        if [ "${OPT_SIDESTORE:-0}" -eq 1 ]; then
            parts+=(sidestore)
        elif [ "${OPT_STRIP_EXTENSIONS:-0}" -eq 1 ]; then
            parts+=(no-ext)
        fi
    else
        [ "${OPT_INJECT:-0}" -eq 1 ] && parts+=(inject)
        [ "${OPT_FFMPEG:-0}" -eq 1 ] && parts+=(ffmpeg)
        [ "${OPT_FLEX:-0}" -eq 1 ] && parts+=(flex)
        [ "${OPT_PATCH:-0}" -eq 1 ] && parts+=(patch)
        if [ "${OPT_SIDESTORE:-0}" -eq 1 ]; then
            parts+=(sidestore)
        elif [ "${OPT_STRIP_EXTENSIONS:-0}" -eq 1 ]; then
            parts+=(no-ext)
        fi
        [ "${OPT_DEV:-0}" -eq 1 ] && parts+=(dev)
    fi
    local IFS=_
    echo "${parts[*]}"
}

sparkle_sideload_output_zip() {
    local flags name
    flags="$(sparkle_flag_token)"
    name="Sparkle"
    [ -n "$flags" ] && name="${name}_${flags}"
    name="${name}_v${SPARKLE_VERSION}_tweaks.zip"
    echo "${name}"
}

# Ensure package output directory exists
mkdir -p "$ROOT_DIR/packages"

# Building modes
if [ "$1" = "ipa" ] || [ "$1" = "sideload" ];
then
    shift
    OPT_INJECT=0
    OPT_FFMPEG=0
    OPT_FLEX=0
    OPT_PATCH=0
    OPT_STRIP_EXTENSIONS=0
    OPT_SIDESTORE=0
    OPT_DEV=0
    OPT_BUNDLE_ID=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --release)
                OPT_INJECT=1
                OPT_FFMPEG=1
                OPT_PATCH=1
                ;;
            --inject) OPT_INJECT=1 ;;
            --ffmpeg) OPT_FFMPEG=1 ;;
            --flex) OPT_FLEX=1 ;;
            --patch) OPT_PATCH=1 ;;
            --no-ext) OPT_STRIP_EXTENSIONS=1 ;;
            --sidestore)
                OPT_INJECT=1
                OPT_FFMPEG=1
                OPT_PATCH=1
                OPT_STRIP_EXTENSIONS=1
                OPT_SIDESTORE=1
                ;;
            --dev) OPT_DEV=1 ;;
            --bundle-id)
                OPT_BUNDLE_ID="$2"
                shift
                ;;
            *)
                echo -e "\033[1m\033[0;31mUnknown package flag: $1\033[0m"
                exit 1
                ;;
        esac
        shift
    done

    # Fallback default targets if no flags were passed
    if [ "$OPT_INJECT" -eq 0 ] && [ "$OPT_FFMPEG" -eq 0 ] && [ "$OPT_FLEX" -eq 0 ] && [ "$OPT_STRIP_EXTENSIONS" -eq 0 ]; then
        OPT_INJECT=1
        OPT_PATCH=1
    fi

    MAKEARGS='SIDELOAD=1 DEBUG=0 FINALPACKAGE=1'
    if [ "$OPT_DEV" -eq 1 ]; then
        MAKEARGS='SIDELOAD=1 DEV=1'
    fi

    if [ "$OPT_FLEX" -eq 1 ]; then
        ensure_flexing_submodule
    fi

    if [ "$OPT_INJECT" -eq 1 ]; then
        if [ "$OPT_DEV" -eq 0 ]; then
            rm -rf "$ROOT_DIR/packages/cache"
        fi
        make clean
        rm -rf .theos
    fi

    echo -e '\033[1m\033[32mSideload compilation...\033[0m'
    if [ "$OPT_INJECT" -eq 1 ]; then
        make $MAKEARGS
    fi
    if [ "$OPT_FLEX" -eq 1 ]; then
        build_flex_library
    fi
    if [ "$OPT_PATCH" -eq 1 ]; then
        build_sideload_fix_library
    fi

    SPARKLEPATH=""
    LIBFLEXPATH=""
    SIDELOADFIXPATH=""
    
    if [ "$OPT_INJECT" -eq 1 ]; then
        SPARKLEPATH="$(theos_dylib_path Sparkle)" || {
            echo -e '\033[1m\033[0;31mCould not find built Sparkle.dylib.\033[0m'
            exit 1
        }
    fi
    if [ "$OPT_FLEX" -eq 1 ]; then
        LIBFLEXPATH="$(theos_dylib_path libFLEX libflex)" || {
            echo -e '\033[1m\033[0;31mCould not find built libFLEX.dylib.\033[0m'
            exit 1
        }
    fi
    if [ "$OPT_PATCH" -eq 1 ]; then
        SIDELOADFIXPATH="$(sideload_fix_dylib_path)" || {
            echo -e '\033[1m\033[0;31mCould not find built SPKSideloadFix.dylib.\033[0m'
            exit 1
        }
    fi
    if [ "$OPT_FFMPEG" -eq 1 ]; then
        ensure_ffmpeg_frameworks
    fi

    # Create staging payload folder structure to gather modifications
    ZIP_OUTPUT_NAME="$(sparkle_sideload_output_zip)"
    zip_out_archive="$ROOT_DIR/packages/${ZIP_OUTPUT_NAME}"
    stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/sparkle-zip-payload.XXXXXX")"
    
    mkdir -p "$stage_dir/Tweaks"
    mkdir -p "$stage_dir/Frameworks"
    mkdir -p "$stage_dir/Resources"

    echo -e '\033[1m\033[32mGathering modifications into ZIP staging payload...\033[0m'

    # Copy primary tweaks and dynamic libraries
    if [ -n "$SPARKLEPATH" ] && [ -f "$SPARKLEPATH" ]; then
        cp -a "$SPARKLEPATH" "$stage_dir/Tweaks/"
    fi
    if [ -n "$LIBFLEXPATH" ] && [ -f "$LIBFLEXPATH" ]; then
        cp -a "$LIBFLEXPATH" "$stage_dir/Tweaks/"
    fi
    if [ -n "$SIDELOADFIXPATH" ] && [ -f "$SIDELOADFIXPATH" ]; then
        cp -a "$SIDELOADFIXPATH" "$stage_dir/Tweaks/"
    fi

    # Copy FFmpeg frameworks if needed
    if [ "$OPT_FFMPEG" -eq 1 ]; then
        for framework in "${FFMPEG_FRAMEWORKS[@]}"; do
            ditto "$framework" "$stage_dir/Frameworks/$(basename "$framework")"
        done
    fi

    # Pack additional core resources, app icon files, and bundles
    if [ -d "$ROOT_DIR/resources/Sparkle.bundle" ]; then
        cp -a "$ROOT_DIR/resources/Sparkle.bundle" "$stage_dir/Resources/"
    fi
    if [ -d "$ROOT_DIR/resources/sparkle_icons" ]; then
        cp -a "$ROOT_DIR/resources/sparkle_icons" "$stage_dir/Resources/"
    fi
    if [ -d "$ROOT_DIR/modules/OpenInstagramSafariExtension.appex" ] && [ "$OPT_STRIP_EXTENSIONS" -eq 0 ]; then
        cp -a "$ROOT_DIR/modules/OpenInstagramSafariExtension.appex" "$stage_dir/Resources/"
    fi

    # Packaging modifications directly into zip
    echo -e '\033[1m\033[32mCompressing modifications and tweaks into ZIP...\033[0m'
    rm -f "$zip_out_archive"
    (
        cd "$stage_dir"
        zip -qry "$zip_out_archive" .
    )
    rm -rf "$stage_dir"

    echo -e "\033[1m\033[32mDone, we hope you enjoy Sparkle!\033[0m\n\nOutput ZIP: $zip_out_archive"

elif [ "$1" = "rootless" ];
then
    make clean
    rm -rf .theos
    echo -e '\033[1m\033[32mBuilding Sparkle tweak for rootless\033[0m'
    export THEOS_PACKAGE_SCHEME=rootless
    make package
    ensure_ffmpeg_frameworks
    DEB_OUT="$(rename_sparkle_deb rootless)"
    echo -e "\033[1m\033[32mDone, we hope you enjoy Sparkle!\033[0m\n\nOutput deb: ${DEB_OUT}"

elif [ "$1" = "rootful" ];
then
    make clean
    rm -rf .theos
    echo -e '\033[1m\033[32mBuilding Sparkle tweak for rootful\033[0m'
    unset THEOS_PACKAGE_SCHEME
    make package
    ensure_ffmpeg_frameworks
    DEB_OUT="$(rename_sparkle_deb rootful)"
    echo -e "\033[1m\033[32mDone, we hope you enjoy Sparkle!\033[0m\n\nOutput deb: ${DEB_OUT}"

else
    echo "Usage: $0 <rootless|rootful|ipa>"
    exit 1
fi
