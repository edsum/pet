#!/usr/bin/env bash
#
# Build and export an iOS IPA for Ad Hoc or App Store distribution.
#
# Examples:
#   ./Scripts/build_ipa.sh adhoc
#   ./Scripts/build_ipa.sh appstore --team-id 2KW7YBLSV9
#   ./Scripts/build_ipa.sh appstore \
#     --profile com.eavic.test="DeskPet AppStore" \
#     --profile com.eavic.test.widget="DeskPetWidget AppStore"
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="DeskPet.xcodeproj"
WORKSPACE=""
SCHEME="DeskPet"
CONFIGURATION="Release"
DESTINATION="generic/platform=iOS"
SDK="iphoneos"

MODE=""
EXPORT_METHOD=""
EXPORT_DESTINATION="export"
SIGNING_STYLE="manual"
TEAM_ID=""
ALLOW_PROVISIONING_UPDATES=false
ALLOW_DEVICE_REGISTRATION=false
CLEAN=true
AUTO_PROFILE_MAPPING=true
USER_SUPPLIED_PROFILES=false
AUTO_DETECTED_PROFILES=false

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_ROOT=""
ARCHIVE_PATH=""
DERIVED_DATA_PATH=""

PROFILE_BUNDLE_IDS=()
PROFILE_NAMES=()

usage() {
    cat <<'EOF'
Usage:
  ./Scripts/build_ipa.sh <adhoc|appstore> [options]
  ./Scripts/build_ipa.sh --type <adhoc|appstore> [options]

Modes:
  adhoc       Export with Xcode method "release-testing" (modern Ad Hoc)
  appstore    Export with Xcode method "app-store-connect"

Options:
  --scheme NAME                       Scheme name. Default: DeskPet
  --configuration NAME                Build configuration. Default: Release
  --project PATH                      .xcodeproj path. Default: DeskPet.xcodeproj
  --workspace PATH                    .xcworkspace path. Overrides --project
  --team-id TEAM_ID                   Developer Team ID used for export/archive
  --signing-style manual|automatic    Export signing style. Default: manual
  --profile BUNDLE_ID=PROFILE_NAME    Manual export profile mapping. Repeatable
  --method METHOD                     Override export method if needed
  --export-dir PATH                   Directory for exported IPA
  --archive-path PATH                 Path for .xcarchive
  --derived-data-path PATH            Optional DerivedData path
  --allow-provisioning-updates        Let xcodebuild manage/download profiles
  --allow-device-registration         Register devices when provisioning updates are allowed
  --no-auto-profiles                  Do not infer manual profile mappings
  --skip-clean                        Skip xcodebuild clean before archive
  -h, --help                          Show this help

Examples:
  ./Scripts/build_ipa.sh adhoc --allow-provisioning-updates

  ./Scripts/build_ipa.sh appstore --team-id 2KW7YBLSV9 \
    --profile com.eavic.test="DeskPet AppStore" \
    --profile com.eavic.test.widget="DeskPetWidget AppStore"

Notes:
  - Xcode 16 renamed export methods: ad-hoc -> release-testing,
    app-store -> app-store-connect.
  - This script exports locally. It does not upload to App Store Connect.
EOF
}

log() { printf "\033[1;36m[info]\033[0m %s\n" "$*"; }
ok() { printf "\033[1;32m[ok]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*" >&2; }
err() { printf "\033[1;31m[error]\033[0m %s\n" "$*" >&2; }

xml_escape() {
    printf "%s" "$1" \
        | sed -e 's/&/\&amp;/g' \
              -e 's/</\&lt;/g' \
              -e 's/>/\&gt;/g' \
              -e 's/"/\&quot;/g' \
              -e "s/'/\&apos;/g"
}

set_mode() {
    case "$1" in
        adhoc|ad-hoc|release-testing)
            MODE="adhoc"
            EXPORT_METHOD="${EXPORT_METHOD:-release-testing}"
            ;;
        appstore|app-store|app-store-connect)
            MODE="appstore"
            EXPORT_METHOD="${EXPORT_METHOD:-app-store-connect}"
            ;;
        *)
            err "Unknown build type: $1"
            usage
            exit 1
            ;;
    esac
}

add_profile_mapping() {
    local mapping="$1"
    local bundle_id="${mapping%%=*}"
    local profile_name="${mapping#*=}"

    if [[ "$bundle_id" == "$mapping" || -z "$bundle_id" || -z "$profile_name" ]]; then
        err "Invalid --profile value: $mapping"
        err "Expected format: --profile com.example.app=\"Profile Name\""
        exit 1
    fi

    PROFILE_BUNDLE_IDS+=("$bundle_id")
    PROFILE_NAMES+=("$profile_name")
    USER_SUPPLIED_PROFILES=true
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        adhoc|ad-hoc|release-testing|appstore|app-store|app-store-connect)
            set_mode "$1"
            shift
            ;;
        --type)
            [[ $# -ge 2 ]] || { err "--type requires a value"; exit 1; }
            set_mode "$2"
            shift 2
            ;;
        --scheme)
            SCHEME="$2"
            shift 2
            ;;
        --configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --workspace)
            WORKSPACE="$2"
            shift 2
            ;;
        --team-id)
            TEAM_ID="$2"
            shift 2
            ;;
        --signing-style)
            SIGNING_STYLE="$2"
            shift 2
            ;;
        --profile)
            add_profile_mapping "$2"
            shift 2
            ;;
        --method)
            EXPORT_METHOD="$2"
            shift 2
            ;;
        --export-dir)
            OUTPUT_ROOT="$2"
            shift 2
            ;;
        --archive-path)
            ARCHIVE_PATH="$2"
            shift 2
            ;;
        --derived-data-path)
            DERIVED_DATA_PATH="$2"
            shift 2
            ;;
        --allow-provisioning-updates)
            ALLOW_PROVISIONING_UPDATES=true
            shift
            ;;
        --allow-device-registration)
            ALLOW_DEVICE_REGISTRATION=true
            shift
            ;;
        --no-auto-profiles)
            AUTO_PROFILE_MAPPING=false
            shift
            ;;
        --skip-clean)
            CLEAN=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            err "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$MODE" ]]; then
    err "Missing build type: adhoc or appstore"
    usage
    exit 1
fi

case "$SIGNING_STYLE" in
    manual|automatic) ;;
    *)
        err "--signing-style must be manual or automatic"
        exit 1
        ;;
esac

cd "$PROJECT_DIR"

if [[ -z "$OUTPUT_ROOT" ]]; then
    OUTPUT_ROOT="$PROJECT_DIR/build/ios/${MODE}-${TIMESTAMP}"
fi
if [[ -z "$ARCHIVE_PATH" ]]; then
    ARCHIVE_PATH="$PROJECT_DIR/build/ios/Archives/${SCHEME}-${MODE}-${TIMESTAMP}.xcarchive"
fi

LOG_DIR="$OUTPUT_ROOT/logs"
EXPORT_OPTIONS_PLIST="$OUTPUT_ROOT/ExportOptions-${MODE}.plist"

mkdir -p "$OUTPUT_ROOT" "$(dirname "$ARCHIVE_PATH")" "$LOG_DIR"

BUILD_WRAPPER=(xcodebuild)
if [[ -n "$WORKSPACE" ]]; then
    [[ -d "$WORKSPACE" ]] || { err "Workspace not found: $WORKSPACE"; exit 1; }
    BUILD_WRAPPER+=("-workspace" "$WORKSPACE")
else
    [[ -d "$PROJECT" ]] || { err "Project not found: $PROJECT"; exit 1; }
    BUILD_WRAPPER+=("-project" "$PROJECT")
fi

COMMON_XCODEBUILD_FLAGS=()
if [[ -n "$DERIVED_DATA_PATH" ]]; then
    COMMON_XCODEBUILD_FLAGS+=("-derivedDataPath" "$DERIVED_DATA_PATH")
fi
if $ALLOW_PROVISIONING_UPDATES; then
    COMMON_XCODEBUILD_FLAGS+=("-allowProvisioningUpdates")
fi
if $ALLOW_DEVICE_REGISTRATION; then
    COMMON_XCODEBUILD_FLAGS+=("-allowProvisioningDeviceRegistration")
fi

ARCHIVE_BUILD_SETTINGS=()
if [[ -n "$TEAM_ID" ]]; then
    ARCHIVE_BUILD_SETTINGS+=("DEVELOPMENT_TEAM=$TEAM_ID")
fi
if [[ "$SIGNING_STYLE" == "automatic" ]]; then
    ARCHIVE_BUILD_SETTINGS+=("CODE_SIGN_STYLE=Automatic" "PROVISIONING_PROFILE_SPECIFIER=")
fi

auto_detect_profile_mappings() {
    if [[ "$SIGNING_STYLE" != "manual" || "$AUTO_PROFILE_MAPPING" != "true" || "${#PROFILE_BUNDLE_IDS[@]}" -gt 0 ]]; then
        return
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not found; cannot infer provisioning profile mappings automatically."
        return
    fi

    local settings_json="$OUTPUT_ROOT/build-settings.json"
    local settings_log="$LOG_DIR/show-build-settings.log"
    local cmd=("${BUILD_WRAPPER[@]}")
    if [[ "${#COMMON_XCODEBUILD_FLAGS[@]}" -gt 0 ]]; then
        cmd+=("${COMMON_XCODEBUILD_FLAGS[@]}")
    fi
    cmd+=(-scheme "$SCHEME" -configuration "$CONFIGURATION" -sdk "$SDK" -showBuildSettings -json)

    log "Detecting manual provisioning profile mappings..."
    set +e
    "${cmd[@]}" >"$settings_json" 2>"$settings_log"
    local status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        warn "Could not read build settings; profile mappings must be passed with --profile."
        warn "See log: $settings_log"
        return
    fi

    local mappings
    mappings="$(python3 - "$settings_json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

seen = set()
for item in data:
    settings = item.get("buildSettings", {})
    bundle_id = (settings.get("PRODUCT_BUNDLE_IDENTIFIER") or "").strip()
    profile = (settings.get("PROVISIONING_PROFILE_SPECIFIER") or "").strip()
    if not bundle_id or not profile or bundle_id in seen:
        continue
    seen.add(bundle_id)
    print(f"{bundle_id}\t{profile}")
PY
)"

    if [[ -z "$mappings" ]]; then
        warn "No manual provisioning profile mappings were found in build settings."
        return
    fi

    local bundle_id
    local profile_name
    while IFS=$'\t' read -r bundle_id profile_name; do
        [[ -n "$bundle_id" && -n "$profile_name" ]] || continue
        PROFILE_BUNDLE_IDS+=("$bundle_id")
        PROFILE_NAMES+=("$profile_name")
        log "Detected profile: $bundle_id -> $profile_name"
    done <<< "$mappings"

    AUTO_DETECTED_PROFILES=true
}

write_export_options() {
    {
        cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>$(xml_escape "$EXPORT_METHOD")</string>
    <key>destination</key>
    <string>$(xml_escape "$EXPORT_DESTINATION")</string>
    <key>signingStyle</key>
    <string>$(xml_escape "$SIGNING_STYLE")</string>
    <key>stripSwiftSymbols</key>
    <true/>
EOF

        if [[ -n "$TEAM_ID" ]]; then
            cat <<EOF
    <key>teamID</key>
    <string>$(xml_escape "$TEAM_ID")</string>
EOF
        fi

        if [[ "$MODE" == "appstore" ]]; then
            cat <<'EOF'
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
EOF
        fi

        if [[ "${#PROFILE_BUNDLE_IDS[@]}" -gt 0 ]]; then
            cat <<'EOF'
    <key>provisioningProfiles</key>
    <dict>
EOF
            local i
            for ((i = 0; i < ${#PROFILE_BUNDLE_IDS[@]}; i++)); do
                cat <<EOF
        <key>$(xml_escape "${PROFILE_BUNDLE_IDS[$i]}")</key>
        <string>$(xml_escape "${PROFILE_NAMES[$i]}")</string>
EOF
            done
            cat <<'EOF'
    </dict>
EOF
        fi

        cat <<'EOF'
</dict>
</plist>
EOF
    } > "$EXPORT_OPTIONS_PLIST"
}

run_xcodebuild() {
    local log_file="$1"
    shift
    set +e
    "$@" 2>&1 | tee "$log_file"
    local status=${PIPESTATUS[0]}
    set -e
    return "$status"
}

auto_detect_profile_mappings
write_export_options

log "Project dir: $PROJECT_DIR"
log "Scheme: $SCHEME"
log "Configuration: $CONFIGURATION"
log "Mode: $MODE"
log "Export method: $EXPORT_METHOD"
log "Archive: $ARCHIVE_PATH"
log "Export dir: $OUTPUT_ROOT"
log "Export options: $EXPORT_OPTIONS_PLIST"

if [[ "$MODE" == "appstore" && "$SIGNING_STYLE" == "manual" && "${#PROFILE_BUNDLE_IDS[@]}" -eq 0 ]]; then
    warn "App Store manual signing usually needs App Store provisioning profile mappings."
    warn "Pass --profile BUNDLE_ID=PROFILE_NAME for the app and extensions, or use --signing-style automatic --allow-provisioning-updates."
elif [[ "$MODE" == "appstore" && "$SIGNING_STYLE" == "manual" && "$AUTO_DETECTED_PROFILES" == "true" && "$USER_SUPPLIED_PROFILES" == "false" ]]; then
    warn "Using auto-detected profile mappings for App Store export."
    warn "Make sure these profiles are App Store distribution profiles, not Ad Hoc profiles."
fi

if $CLEAN; then
    log "Cleaning..."
    CLEAN_CMD=("${BUILD_WRAPPER[@]}")
    if [[ "${#COMMON_XCODEBUILD_FLAGS[@]}" -gt 0 ]]; then
        CLEAN_CMD+=("${COMMON_XCODEBUILD_FLAGS[@]}")
    fi
    CLEAN_CMD+=(clean -scheme "$SCHEME" -configuration "$CONFIGURATION" -sdk "$SDK")
    run_xcodebuild "$LOG_DIR/clean.log" "${CLEAN_CMD[@]}"
    ok "Clean finished"
fi

log "Archiving..."
rm -rf "$ARCHIVE_PATH"
ARCHIVE_CMD=("${BUILD_WRAPPER[@]}")
if [[ "${#COMMON_XCODEBUILD_FLAGS[@]}" -gt 0 ]]; then
    ARCHIVE_CMD+=("${COMMON_XCODEBUILD_FLAGS[@]}")
fi
ARCHIVE_CMD+=(archive
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -sdk "$SDK"
    -destination "$DESTINATION"
    -archivePath "$ARCHIVE_PATH")
if [[ "${#ARCHIVE_BUILD_SETTINGS[@]}" -gt 0 ]]; then
    ARCHIVE_CMD+=("${ARCHIVE_BUILD_SETTINGS[@]}")
fi
run_xcodebuild "$LOG_DIR/archive.log" "${ARCHIVE_CMD[@]}"
ok "Archive finished"

log "Exporting IPA..."
EXPORT_CMD=(xcodebuild)
if [[ "${#COMMON_XCODEBUILD_FLAGS[@]}" -gt 0 ]]; then
    EXPORT_CMD+=("${COMMON_XCODEBUILD_FLAGS[@]}")
fi
EXPORT_CMD+=(-exportArchive
    -archivePath "$ARCHIVE_PATH"
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
    -exportPath "$OUTPUT_ROOT")
run_xcodebuild "$LOG_DIR/export.log" "${EXPORT_CMD[@]}"
ok "Export finished"

IPA_FILES=()
while IFS= read -r ipa; do
    IPA_FILES+=("$ipa")
done < <(find "$OUTPUT_ROOT" -maxdepth 1 -name "*.ipa" -type f | sort)

if [[ "${#IPA_FILES[@]}" -eq 0 ]]; then
    err "Export finished but no IPA was found in: $OUTPUT_ROOT"
    err "Check log: $LOG_DIR/export.log"
    exit 1
fi

ok "IPA generated:"
for ipa in "${IPA_FILES[@]}"; do
    printf "  %s\n" "$ipa"
done
