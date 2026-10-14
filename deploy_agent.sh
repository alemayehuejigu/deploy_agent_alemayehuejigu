#!/usr/bin/env bash
# ==============================================================================
# Script Name : deploy_agent.sh
# Description : Automated Project Bootstrapping & Process Management for
#               Student Attendance Tracker application.
# Author      : Bethelhem Alemayehu Ejigu (alemayehuejigu)
# Features    :
#   1. Deploy Application (Structure creation, Roster configuration, Permissions)
#   2. Run Application (Interactive attendance checking session)
#   3. Archive Logs (Timestamped logs in designated archive directories)
# Signal Trap : Graceful SIGINT / SIGTSTP handling with automatic archiving & cleanup
# ==============================================================================

# Ensure script runs from the repository root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

TEMPLATES_DIR="$SCRIPT_DIR/templates"
TEMPLATE_PY="$TEMPLATES_DIR/attendance_checker.py"
TEMPLATE_CONFIG="$TEMPLATES_DIR/config.json"
TEMPLATE_ASSETS="$TEMPLATES_DIR/assets.csv"

# Global state for trap handling
DEPLOY_ACTIVE=0
CURRENT_PROJECT_DIR=""

# Sample student bank for Option B (Fresh roster generation)
SAMPLE_NAMES=(
    "Ada Lovelace"
    "Alan Turing"
    "Grace Hopper"
    "Margaret Hamilton"
    "Dennis Ritchie"
    "Ken Thompson"
    "Linus Torvalds"
    "Guido van Rossum"
    "Barbara Liskov"
    "Katherine Johnson"
    "Tim Berners-Lee"
    "Hedy Lamarr"
)

SAMPLE_EMAILS=(
    "ada@example.com"
    "alan@example.com"
    "grace@example.com"
    "margaret@example.com"
    "dennis@example.com"
    "ken@example.com"
    "linus@example.com"
    "guido@example.com"
    "barbara@example.com"
    "katherine@example.com"
    "tim@example.com"
    "hedy@example.com"
)

# ------------------------------------------------------------------------------
# Signal Trap Handler: SIGINT (Ctrl+C) & SIGTSTP (Ctrl+Z)
# ------------------------------------------------------------------------------
cleanup_on_interrupt() {
    echo ""
    echo "======================================================================"
    echo "[!] INTERRUPT DETECTED: Deployment process was aborted by user signal."
    echo "======================================================================"
    if [ "$DEPLOY_ACTIVE" -eq 1 ] && [ -n "$CURRENT_PROJECT_DIR" ] && [ -d "$CURRENT_PROJECT_DIR" ]; then
        ARCHIVE_FILE="${CURRENT_PROJECT_DIR}_archive.zip"
        echo "[*] Archiving incomplete project state to '$ARCHIVE_FILE'..."
        if zip -rq "$ARCHIVE_FILE" "$CURRENT_PROJECT_DIR"; then
            echo "[+] Recovery archive successfully created: $ARCHIVE_FILE"
        else
            echo "[!] Warning: zip utility encountered an issue creating $ARCHIVE_FILE"
        fi

        echo "[*] Deleting incomplete directory '$CURRENT_PROJECT_DIR' to prevent workspace clutter..."
        rm -rf "$CURRENT_PROJECT_DIR"
        echo "[+] Cleanup completed successfully."
    else
        echo "[*] No partial deployment directory found to clean up."
    fi
    echo "[*] Exiting cleanly."
    exit 130
}

# ------------------------------------------------------------------------------
# Pre-Flight Environment Validation
# ------------------------------------------------------------------------------
check_preflight_requirements() {
    echo "----------------------------------------------------------------------"
    echo "[*] Running pre-flight environment checks..."
    local failed=0

    # 1. Verify python3 installation & version
    if command -v python3 >/dev/null 2>&1; then
        PY_VERSION=$(python3 --version 2>&1)
        echo "  [OK] python3 detected: $PY_VERSION"
    else
        echo "  [FAIL] python3 is NOT installed or not found in system PATH."
        failed=1
    fi

    # 2. Verify zip utility installation
    if command -v zip >/dev/null 2>&1; then
        ZIP_VERSION=$(zip -v 2>&1 | head -n 1)
        echo "  [OK] zip detected: $ZIP_VERSION"
    else
        echo "  [FAIL] zip utility is NOT installed or not found in system PATH."
        failed=1
    fi

    # 3. Verify templates exist
    if [ ! -f "$TEMPLATE_PY" ] || [ ! -f "$TEMPLATE_CONFIG" ] || [ ! -f "$TEMPLATE_ASSETS" ]; then
        echo "  [FAIL] Missing required template files in '$TEMPLATES_DIR'."
        echo "         Expected: attendance_checker.py, config.json, assets.csv"
        failed=1
    else
        echo "  [OK] Template files verified in '$TEMPLATES_DIR'."
    fi

    if [ "$failed" -ne 0 ]; then
        echo "[-] Pre-flight checks failed. Please install missing prerequisites and retry."
        return 1
    fi

    echo "[+] All pre-flight checks passed."
    echo "----------------------------------------------------------------------"
    return 0
}

# ------------------------------------------------------------------------------
# Helper: Validate Integer Input
# ------------------------------------------------------------------------------
is_positive_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

is_valid_percentage() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 0 ] && [ "$1" -le 100 ]
}

# ------------------------------------------------------------------------------
# Feature 1: Deploy the Application
# ------------------------------------------------------------------------------
deploy_application() {
    echo ""
    echo "======================================================================"
    echo "                FEATURE 1: DEPLOY APPLICATION"
    echo "======================================================================"

    # Run pre-flight checks first
    if ! check_preflight_requirements; then
        return 1
    fi

    # Prompt user for project name
    local proj_input=""
    while [ -z "$proj_input" ]; do
        if ! read -r -p "Enter project directory suffix/name (e.g. v1, demo, classA): " proj_input; then
            echo ""
            return 1
        fi
        proj_input=$(echo "$proj_input" | tr -d '[:space:]')
        if [ -z "$proj_input" ]; then
            echo "[!] Project name cannot be empty. Please enter a valid identifier."
        fi
    done

    local project_dir="attendance_tracker_${proj_input}"

    # Check if target directory already exists
    if [ -d "$project_dir" ]; then
        echo "[!] Warning: Directory '$project_dir' already exists."
        if ! read -r -p "Do you want to overwrite it? (y/N): " confirm_overwrite; then
            echo ""
            return 1
        fi
        case "$confirm_overwrite" in
            [yY]|[yY][eE][sS])
                echo "[*] Removing existing directory '$project_dir'..."
                rm -rf "$project_dir"
                ;;
            *)
                echo "[-] Deployment aborted by user to prevent overwriting existing data."
                return 1
                ;;
        esac
    fi

    # Activate signal trap for atomic creation
    CURRENT_PROJECT_DIR="$project_dir"
    DEPLOY_ACTIVE=1
    trap cleanup_on_interrupt SIGINT SIGTSTP

    echo "[*] Initializing deployment for '$project_dir'..."

    # Step 1: Create exact directory architecture
    if ! mkdir -p "$project_dir/Helpers" "$project_dir/reports" "$project_dir/archives/attendance" "$project_dir/archives/absent"; then
        echo "[-] Error: Failed to create directories for '$project_dir'. Permission denied."
        DEPLOY_ACTIVE=0
        trap - SIGINT SIGTSTP
        return 1
    fi
    echo "[+] Created required directory structure:"
    echo "    $project_dir/"
    echo "    ├── Helpers/"
    echo "    ├── reports/ (empty)"
    echo "    └── archives/ (attendance/, absent/)"

    # Step 2: Deploy attendance_checker.py unmodified
    if ! cp "$TEMPLATE_PY" "$project_dir/attendance_checker.py"; then
        echo "[-] Error: Failed to copy attendance_checker.py."
        return 1
    fi
    echo "[+] Deployed attendance_checker.py from templates."

    # Step 3: Deploy config.json template
    if ! cp "$TEMPLATE_CONFIG" "$project_dir/Helpers/config.json"; then
        echo "[-] Error: Failed to copy config.json."
        return 1
    fi
    echo "[+] Deployed Helpers/config.json from templates."

    # Step 4: Configure Helpers/assets.csv (Roster building)
    echo ""
    echo "Choose roster generation method:"
    echo "  [A] Copy from sample template (pre-populated with 4 historical sessions)"
    echo "  [B] Generate a fresh roster from scratch (starts at 0 sessions)"
    local roster_choice=""
    while [[ ! "$roster_choice" =~ ^[AaBb]$ ]]; do
        if ! read -r -p "Select option [A/B]: " roster_choice; then
            echo ""
            return 1
        fi
    done

    if [[ "$roster_choice" =~ ^[Aa]$ ]]; then
        # Option A: Copy from template
        local total_template_rows
        total_template_rows=$(($(wc -l < "$TEMPLATE_ASSETS") - 1))
        local count_to_copy=0
        while true; do
            if ! read -r -p "How many students would you like to copy? (1-$total_template_rows): " count_to_copy; then
                echo ""
                return 1
            fi
            if is_positive_integer "$count_to_copy" && [ "$count_to_copy" -le "$total_template_rows" ]; then
                break
            fi
            echo "[!] Please enter a valid number between 1 and $total_template_rows."
        done

        head -n "$((count_to_copy + 1))" "$TEMPLATE_ASSETS" > "$project_dir/Helpers/assets.csv"
        echo "[+] Successfully copied $count_to_copy student records from template to Helpers/assets.csv."
        echo "[+] Configured total_sessions remains 5 (consistent with 4 prior sessions)."

    else
        # Option B: Generate fresh roster
        local count_to_generate=0
        local max_sample="${#SAMPLE_NAMES[@]}"
        while true; do
            if ! read -r -p "How many students would you like to generate? (1-$max_sample): " count_to_generate; then
                echo ""
                return 1
            fi
            if is_positive_integer "$count_to_generate" && [ "$count_to_generate" -le "$max_sample" ]; then
                break
            fi
            echo "[!] Please enter a valid number between 1 and $max_sample."
        done

        echo "Email,Names,Attendance Count,Absence Count" > "$project_dir/Helpers/assets.csv"
        for ((i=0; i<count_to_generate; i++)); do
            echo "${SAMPLE_EMAILS[$i]},${SAMPLE_NAMES[$i]},0,0" >> "$project_dir/Helpers/assets.csv"
        done
        echo "[+] Generated fresh roster with $count_to_generate students in Helpers/assets.csv."

        # Keep total_sessions consistent: fresh roster means session 1
        sed -i.bak -E 's/("total_sessions":[[:space:]]*)[0-9]+/\11/' "$project_dir/Helpers/config.json"
        rm -f "$project_dir/Helpers/config.json.bak"
        echo "[+] Updated Helpers/config.json total_sessions to 1 (consistent with fresh roster session 1)."
    fi

    # Step 5: Set and verify permissions
    echo ""
    echo "[*] Setting file permissions..."
    chmod +x "$project_dir/attendance_checker.py"
    chmod 600 "$project_dir/Helpers/config.json"
    echo "[OK] Permissions applied:"
    echo "     - $project_dir/attendance_checker.py -> executable (chmod +x)"
    echo "     - $project_dir/Helpers/config.json   -> restricted read/write owner only (chmod 600)"

    # Step 6: Offer to update attendance alert thresholds
    echo ""
    if ! read -r -p "Would you like to customize attendance alert thresholds in config.json? (y/N): " update_thresholds; then
        echo ""
        update_thresholds="N"
    fi
    case "$update_thresholds" in
        [yY]|[yY][eE][sS])
            local new_warning=""
            local new_failure=""

            while true; do
                if ! read -r -p "Enter new warning threshold percentage [default 75]: " new_warning; then
                    echo ""
                    return 1
                fi
                new_warning="${new_warning:-75}"
                if is_valid_percentage "$new_warning"; then
                    break
                fi
                echo "[!] Invalid input: threshold must be a number between 0 and 100."
            done

            while true; do
                if ! read -r -p "Enter new failure threshold percentage [default 50]: " new_failure; then
                    echo ""
                    return 1
                fi
                new_failure="${new_failure:-50}"
                if is_valid_percentage "$new_failure"; then
                    if [ "$new_failure" -le "$new_warning" ]; then
                        break
                    else
                        echo "[!] Failure threshold ($new_failure%) cannot exceed warning threshold ($new_warning%)."
                    fi
                else
                    echo "[!] Invalid input: threshold must be a number between 0 and 100."
                fi
            done

            echo "[*] Updating thresholds with sed in '$project_dir/Helpers/config.json'..."
            sed -i.bak -E "s/(\"warning\":[[:space:]]*)[0-9]+/\1$new_warning/" "$project_dir/Helpers/config.json"
            sed -i.bak -E "s/(\"failure\":[[:space:]]*)[0-9]+/\1$new_failure/" "$project_dir/Helpers/config.json"
            rm -f "$project_dir/Helpers/config.json.bak"
            echo "[+] Updated thresholds: warning = $new_warning%, failure = $new_failure%."
            ;;
        *)
            echo "[*] Keeping default alert thresholds (warning: 75%, failure: 50%)."
            ;;
    esac

    # Deployment complete: disarm trap before launching interactive application
    DEPLOY_ACTIVE=0
    trap - SIGINT SIGTSTP
    echo ""
    echo "======================================================================"
    echo "[+] Deployment of '$project_dir' completed successfully!"
    echo "======================================================================"

    # Step 7: Verification via execution (Feature 2)
    echo "[*] Launching application verification run (Feature 2)..."
    run_application "$proj_input"
}

# ------------------------------------------------------------------------------
# Feature 2: Run the Application
# ------------------------------------------------------------------------------
run_application() {
    local proj_input="$1"
    echo ""
    echo "======================================================================"
    echo "                  FEATURE 2: RUN APPLICATION"
    echo "======================================================================"

    if [ -z "$proj_input" ]; then
        if ! read -r -p "Enter deployed project directory suffix/name to run: " proj_input; then
            echo ""
            return 1
        fi
        proj_input=$(echo "$proj_input" | tr -d '[:space:]')
    fi

    local project_dir="attendance_tracker_${proj_input}"

    if [ ! -d "$project_dir" ]; then
        echo "[-] Error: Project directory '$project_dir' does not exist."
        echo "    Please run Feature 1 to deploy it first."
        return 1
    fi

    if [ ! -f "$project_dir/attendance_checker.py" ]; then
        echo "[-] Error: '$project_dir/attendance_checker.py' not found."
        return 1
    fi

    echo "[*] Entering '$project_dir' and executing attendance_checker.py..."
    echo "----------------------------------------------------------------------"
    (
        cd "$project_dir" || exit 1
        python3 attendance_checker.py
    )
    local exit_code=$?
    echo "----------------------------------------------------------------------"

    if [ $exit_code -eq 0 ]; then
        echo "[+] Application session finished cleanly."
    else
        echo "[!] Application exited with status code $exit_code."
    fi

    return $exit_code
}

# ------------------------------------------------------------------------------
# Feature 3: Archive the Log Files
# ------------------------------------------------------------------------------
archive_logs() {
    local proj_input="$1"
    echo ""
    echo "======================================================================"
    echo "                 FEATURE 3: ARCHIVE LOG FILES"
    echo "======================================================================"

    if [ -z "$proj_input" ]; then
        if ! read -r -p "Enter deployed project directory suffix/name to archive logs: " proj_input; then
            echo ""
            return 1
        fi
        proj_input=$(echo "$proj_input" | tr -d '[:space:]')
    fi

    local project_dir="attendance_tracker_${proj_input}"

    if [ ! -d "$project_dir" ]; then
        echo "[-] Error: Project directory '$project_dir' does not exist."
        return 1
    fi

    local reports_dir="$project_dir/reports"
    local archives_dir="$project_dir/archives"
    local att_archive_dir="$archives_dir/attendance"
    local abs_archive_dir="$archives_dir/absent"

    # Ensure archive destinations exist
    mkdir -p "$att_archive_dir" "$abs_archive_dir"

    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local archived_count=0

    echo "[*] Inspecting reports directory: '$reports_dir'..."

    # Check attendance.log
    local att_log="$reports_dir/attendance.log"
    if [ -f "$att_log" ]; then
        local dest_att="$att_archive_dir/attendance_${timestamp}.log"
        cp "$att_log" "$dest_att"
        echo "[+] Archived attendance log:"
        echo "    Source : $att_log"
        echo "    Target : $dest_att"
        archived_count=$((archived_count + 1))
    else
        echo "[i] reports/attendance.log was not found (no attendance recorded)."
    fi

    # Check absent.log
    local abs_log="$reports_dir/absent.log"
    if [ -f "$abs_log" ]; then
        local dest_abs="$abs_archive_dir/absent_${timestamp}.log"
        cp "$abs_log" "$dest_abs"
        echo "[+] Archived absent log:"
        echo "    Source : $abs_log"
        echo "    Target : $dest_abs"
        archived_count=$((archived_count + 1))
    else
        echo "[i] reports/absent.log was not found (e.g., zero absences recorded). Handled gracefully."
    fi

    echo "----------------------------------------------------------------------"
    if [ "$archived_count" -gt 0 ]; then
        echo "[+] Archival complete. Total log files archived: $archived_count."
    else
        echo "[i] No new log files were present to archive in '$reports_dir'."
    fi
    echo "----------------------------------------------------------------------"
}

# ------------------------------------------------------------------------------
# Interactive Menu
# ------------------------------------------------------------------------------
show_menu() {
    while true; do
        echo ""
        echo "======================================================================"
        echo "      Automated Project Bootstrapping & Process Management Menu       "
        echo "======================================================================"
        echo "  1) Deploy the Application (Feature 1)"
        echo "  2) Run the Application (Feature 2)"
        echo "  3) Archive Log Files (Feature 3)"
        echo "  4) Run Pre-flight Environment Checks"
        echo "  5) Exit"
        echo "======================================================================"
        if ! read -r -p "Please select an option [1-5]: " menu_choice; then
            echo ""
            exit 0
        fi

        case "$menu_choice" in
            1)
                deploy_application
                ;;
            2)
                run_application
                ;;
            3)
                archive_logs
                ;;
            4)
                check_preflight_requirements
                ;;
            5)
                echo "[*] Exiting deploy_agent. Goodbye!"
                exit 0
                ;;
            *)
                echo "[!] Invalid option. Please select 1, 2, 3, 4, or 5."
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Usage / Help
# ------------------------------------------------------------------------------
show_help() {
    cat << EOF
Usage: $0 [COMMAND] [ARGS]

Commands:
  deploy                 Deploy a new attendance tracker project instance
  run [NAME]             Run the attendance checker on an existing project
  archive [NAME]         Archive logs for a deployed project
  check                  Run pre-flight environment checks
  menu                   Launch interactive selection menu (default if no args)
  help, -h, --help       Show this help message

Examples:
  $0 deploy              # Interactive deployment workflow
  $0 run v1              # Directly run attendance_tracker_v1
  $0 archive v1          # Archive reports for attendance_tracker_v1
  $0                     # Opens the interactive menu
EOF
}

# ------------------------------------------------------------------------------
# Main Entry Point
# ------------------------------------------------------------------------------
case "${1:-menu}" in
    deploy)
        deploy_application
        ;;
    run)
        run_application "$2"
        ;;
    archive)
        archive_logs "$2"
        ;;
    check)
        check_preflight_requirements
        ;;
    menu)
        show_menu
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        echo "[!] Unknown command: $1"
        show_help
        exit 1
        ;;
esac
