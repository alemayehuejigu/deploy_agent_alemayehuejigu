# deploy_agent_alemayehuejigu

Automated Project Bootstrapping & Process Management for the Student Attendance Tracker.

[![Author](https://img.shields.io/badge/Author-Bethelhem%20Alemayehu%20Ejigu-blue.svg)](https://github.com/alemayehuejigu)
[![Course](https://img.shields.io/badge/Course-Intro%20to%20Linux%20%26%20IT%20Tools-brightgreen.svg)](#)
[![Institution](https://img.shields.io/badge/Institution-ALU-red.svg)](https://www.alueducation.com/)

---

## Walkthrough Video

> [!IMPORTANT]
> **Video Demonstration Link**:  
> **[Watch the Run-Through Video Presentation](YOUR_VIDEO_LINK_HERE)**  
>  
> *(To finalize before grading: upload your recording to YouTube as Unlisted, Loom, or Google Drive with 'Anyone with the link can view' permission, replace `YOUR_VIDEO_LINK_HERE` above, then commit and push).*

---

## Table of Contents
1. [Project Overview & Infrastructure as Code (IaC)](#project-overview--the-power-of-iac)
2. [Folder Architecture](#folder-architecture)
3. [Script Features & Logic Deep Dive](#script-features--logic-deep-dive)
   - [Feature 1: Deploy the Application](#feature-1-deploy-the-application)
   - [Feature 2: Run the Application](#feature-2-run-the-application)
   - [Feature 3: Archive Log Files](#feature-3-archive-log-files)
4. [Signal Trapping & Process Management](#signal-trapping--process-management-ctrlc--ctrlz)
   - [How the Signal Trap Works](#how-the-signal-trap-works)
   - [Testing the Interruption Path](#testing-the-interruption-path)
   - [Recovery Archive Contents](#recovery-archive-contents)
5. [Alert Threshold Modification (Sed Logic)](#alert-threshold-modification-sed-logic)
6. [How to Run the Script](#how-to-run-the-script)
   - [Interactive Menu Mode](#interactive-menu-mode)
   - [CLI Flags / Subcommand Mode](#cli-flags--subcommand-mode)
7. [Testing & Verification Methodology](#testing--verification-methodology)
8. [Walkthrough Video Script & Demo Guide](#walkthrough-video-script--demo-guide)

---

## Project Overview & The Power of IaC

Manual configuration and deployment of application environments are prone to human mistakes, configuration drift, and developer downtime. In professional software engineering, **Infrastructure as Code (IaC)** and automated bootstrapping solve these issues:
- **Reproducibility**: Guarantees that every developer, test system, and server operates in an identical directory structure with uniform file permissions.
- **Efficiency**: Reduces setup from 10 minutes of error-prone terminal commands to a single multi-second automated execution.
- **Reliability**: Eliminates missing file paths, corrupted rosters, or permission oversights through programmatic pre-flight checks and signal traps.

`deploy_agent.sh` manages the lifecycle of the **Student Attendance Tracker** Python application, encompassing automated pre-flight checks, directory scaffolding, roster management, security permissions, alert threshold configuration, interactive process execution, log archival, and interrupt recovery.

---

## Folder Architecture

### 1. Master Repository Structure
```text
deploy_agent/
├── deploy_agent.sh          # Master orchestration shell script
├── README.md                # Comprehensive documentation
└── templates/               # Unmodified source files
    ├── attendance_checker.py # Interactive attendance tracking application
    ├── assets.csv           # Master sample roster (10 students, 4 prior sessions)
    └── config.json          # Application configuration & alert thresholds
```

### 2. Deployed Project Structure (`attendance_tracker_{input}/`)
When Feature 1 deploys an instance (e.g. `attendance_tracker_v1`), it generates this exact structure:
```text
attendance_tracker_{input}/
├── attendance_checker.py     # Executable permissions (chmod +x)
├── Helpers/
│   ├── assets.csv           # Class roster (Option A or Option B)
│   └── config.json          # Thresholds & session config (chmod 600)
├── reports/                 # Application output directory (initially empty)
│   ├── attendance.log       # Created dynamically on live session run
│   └── absent.log           # Created dynamically when absences occur
└── archives/                # Feature 3 log backup destination
    ├── attendance/          # e.g., attendance_YYYYMMDD_HHMMSS.log
    └── absent/              # e.g., absent_YYYYMMDD_HHMMSS.log
```

---

## Script Features & Logic Deep Dive

### Feature 1: Deploy the Application

The deployment workflow (`deploy_application`) systematically builds and verifies the environment:

1. **Pre-flight Environment Checks (`check_preflight_requirements`)**:
   - Executes `python3 --version` to ensure Python 3 is installed and callable.
   - Executes `zip -v` to ensure the `zip` utility is available for interrupt recovery.
   - Validates that `templates/attendance_checker.py`, `templates/config.json`, and `templates/assets.csv` exist before performing any actions.
   - If any prerequisite fails, the script halts early with an actionable error.

2. **Project Naming & Overwrite Protection**:
   - Prompts the user for a project suffix/name via `read` (e.g., `v1`).
   - Targets `attendance_tracker_{input}/`.
   - If the directory already exists, it prompts `Do you want to overwrite it? (y/N): `.
   - If confirmed with `y`/`Y`, it cleanly purges the old directory with `rm -rf`. If rejected, it aborts immediately to protect existing data.

3. **Atomic Scaffolding & Signal Trap Activation**:
   - Enables `trap cleanup_on_interrupt SIGINT SIGTSTP`.
   - Creates `Helpers/`, `reports/`, `archives/attendance/`, and `archives/absent/`.

4. **Template Deployment & Roster Generation (Option A vs Option B)**:
   - Deploys `templates/attendance_checker.py` and `templates/config.json`.
   - Offers the user two paths for building `Helpers/assets.csv`:
     - **Option A (Copy from Template)**:
       Prompts the user for the number of student records to copy (1 to total available rows). It copies the header plus $N$ rows using `head -n $((N + 1))`. Since template rows reflect 4 historical sessions, `total_sessions` remains at default `5` (4 prior + 1 today).
     - **Option B (Generate Fresh Roster)**:
       Prompts for the number of students to generate. It writes the CSV header and generates rows from built-in student name/email arrays with `Attendance Count` and `Absence Count` initialized to `0`. It then automatically updates `total_sessions` in `Helpers/config.json` to `1` using `sed`, maintaining consistency for the first session.

5. **Permission Hardening**:
   - Enforces `chmod +x "$project_dir/attendance_checker.py"` so the script can be directly executed.
   - Restricts sensitive grading and alert configuration with `chmod 600 "$project_dir/Helpers/config.json"` (read/write only by file owner).
   - Prints clear terminal confirmation of the permissions applied.

6. **Attendance Alert Threshold Modification**:
   - Prompts the user whether to modify alert thresholds.
   - If affirmative, prompts for `warning` (default 75%) and `failure` (default 50%).
   - Performs strict numerical regex validation (`^[0-9]+$`), bounds checking ($0 \le \text{threshold} \le 100$), and ensures `failure <= warning`.
   - Applies in-place modifications using `sed` without altering JSON ordering or formatting.

7. **Deployment Verification via Execution**:
   - Immediately invokes Feature 2 upon completing deployment. Successfully running the app confirms that directory paths, roster columns, permissions, and configuration operate seamlessly together.

---

### Feature 2: Run the Application

The execution workflow (`run_application`):
- Prompts for the project suffix/name (or uses command-line argument `$1` or inherited parameter from Feature 1).
- Validates the existence of `attendance_tracker_{input}` and `attendance_checker.py`.
- Enters the directory (`cd "$project_dir"`) and runs `python3 attendance_checker.py`.
- Hands standard input/output directly to the instructor to mark attendance (`P` for Present, `A` for Absent).
- Upon session conclusion, returns cleanly to the parent workspace.

---

### Feature 3: Archive Log Files

The archival workflow (`archive_logs`):
- Targets the project's `reports/` directory.
- Captures an ISO-standard timestamp: `TIMESTAMP=$(date +"%Y%m%d_%H%M%S")`.
- **Attendance Log Handling**:
  - Checks if `reports/attendance.log` exists.
  - If present, copies it to `archives/attendance/attendance_${TIMESTAMP}.log`.
  - Prints the source and destination paths.
- **Absent Log Handling & Graceful Non-Existent File Management**:
  - Checks if `reports/absent.log` exists.
  - If present, copies it to `archives/absent/absent_${TIMESTAMP}.log`.
  - If absent (e.g. all students were present, so no absences were recorded), the script logs an informative message (`[i] reports/absent.log was not found (zero absences). Handled gracefully.`) and completes without error.

---

## Signal Trapping & Process Management (Ctrl+C / Ctrl+Z & Error Cleanup)

### How the Signal Trap & Cleanup Work
During Feature 1 deployment, an unexpected interruption (e.g. accidental `Ctrl+C` / `SIGINT` or `Ctrl+Z` / `SIGTSTP`), a closed input stream, or a system permission denial could leave half-copied files or corrupted directories in the workspace.

`deploy_agent.sh` provides bulletproof process management through two complementary mechanisms:

1. **Signal Trap (`cleanup_on_interrupt`)**:
   Traps POSIX signals `SIGINT` and `SIGTSTP` during active project scaffolding:
   ```bash
   cleanup_on_interrupt() {
       echo "[!] INTERRUPT DETECTED: Deployment process was aborted by user signal."
       if [ "$DEPLOY_ACTIVE" -eq 1 ] && [ -n "$CURRENT_PROJECT_DIR" ] && [ -d "$CURRENT_PROJECT_DIR" ]; then
           local archive_file="${CURRENT_PROJECT_DIR}_archive.zip"
           echo "[*] Archiving incomplete project state to '$archive_file'..."
           zip -rq "$archive_file" "$CURRENT_PROJECT_DIR"
           echo "[*] Deleting incomplete directory '$CURRENT_PROJECT_DIR' to prevent workspace clutter..."
           rm -rf "$CURRENT_PROJECT_DIR"
           echo "[+] Cleanup completed successfully."
       fi
       DEPLOY_ACTIVE=0
       trap - SIGINT SIGTSTP
       exit 130
   }
   trap cleanup_on_interrupt SIGINT SIGTSTP
   ```

2. **Atomic Failure Cleanup (`fail_deploy`)**:
   If an operation encounters a permission denial, an unreadable template, or an unexpected end of input, `fail_deploy` guarantees the exact same clean state: it bundles the partial state into a recovery `.zip`, deletes the incomplete folder, disarms the trap, and exits gracefully with an error message instead of leaving half-made directories behind.

### Testing the Interruption Path (Interactive Demo)

To demonstrate the signal trap in your walkthrough video:
1. Run `./deploy_agent.sh deploy`.
2. Enter a project name (e.g. `interrupt_demo`).
3. The script initializes the directory structure and templates, then pauses at the prompt:
   ```text
   Choose roster generation method:
     [A] Copy from sample template (pre-populated with 4 historical sessions)
     [B] Generate a fresh roster from scratch (starts at 0 sessions)
   Select option [A/B]:
   ```
4. Press **`Ctrl + C`**.
5. Observe the clean terminal recovery:
   ```text
   ======================================================================
   [!] INTERRUPT DETECTED: Deployment process was aborted by user signal.
   ======================================================================
   [*] Archiving incomplete project state to 'attendance_tracker_interrupt_demo_archive.zip'...
   [+] Recovery archive successfully created: attendance_tracker_interrupt_demo_archive.zip
   [*] Deleting incomplete directory 'attendance_tracker_interrupt_demo' to prevent workspace clutter...
   [+] Cleanup completed successfully.
   [*] Exiting cleanly.
   ```
6. Verify with `ls -la attendance_tracker_interrupt_demo*`:
   - `attendance_tracker_interrupt_demo/` has been completely deleted.
   - `attendance_tracker_interrupt_demo_archive.zip` exists and contains the recovery files.

### Recovery Archive Contents
Inspect the created recovery archive with `unzip -l`:
```bash
unzip -l attendance_tracker_interrupt_demo_archive.zip
```
Real output:
```text
Archive:  attendance_tracker_interrupt_demo_archive.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
     4392  2026-10-14 15:57   attendance_tracker_interrupt_demo/attendance_checker.py
      108  2026-10-14 15:57   attendance_tracker_interrupt_demo/Helpers/config.json
---------                     -------
     4500                     2 files
```

---

## Alert Threshold Modification (Sed Logic)

The script updates attendance thresholds in place using stream editing (`sed`).

### Regex Pattern
```bash
sed -i.bak -E "s/(\"warning\":[[:space:]]*)[0-9]+/\1$new_warning/" "$project_dir/Helpers/config.json"
sed -i.bak -E "s/(\"failure\":[[:space:]]*)[0-9]+/\1$new_failure/" "$project_dir/Helpers/config.json"
rm -f "$project_dir/Helpers/config.json.bak"
```

### Why this sed expression is robust:
- Matches key `"warning":` or `"failure":` followed by optional whitespace and digits (`[0-9]+`).
- Preserves indentation, spacing, quotation marks, and line ordering.
- Uses `-i.bak` followed by removal of `.bak` to maintain cross-platform compatibility across both GNU `sed` (Linux / Git Bash) and BSD `sed` (macOS).

---

## How to Run the Script

### Interactive Menu Mode
Run without arguments to launch the interactive interface:
```bash
./deploy_agent.sh
```
Output:
```text
======================================================================
      Automated Project Bootstrapping & Process Management Menu       
======================================================================
  1) Deploy the Application (Feature 1)
  2) Run the Application (Feature 2)
  3) Archive Log Files (Feature 3)
  4) Run Pre-flight Environment Checks
  5) Exit
======================================================================
Please select an option [1-5]: 
```

### CLI Flags / Subcommand Mode
For automated scripting and power users:
```bash
# Display help and usage
./deploy_agent.sh help

# Run pre-flight checks
./deploy_agent.sh check

# Deploy a new instance interactively
./deploy_agent.sh deploy

# Run attendance checker for an existing project
./deploy_agent.sh run v1

# Archive reports for an existing project
./deploy_agent.sh archive v1
```

---

## Testing & Verification Methodology

Every feature and edge case was tested against the project requirements:

| Test Case | Procedure | Expected Result | Result |
|---|---|---|---|
| **Pre-flight Check** | Run `./deploy_agent.sh check` | Verifies `python3`, `zip`, and `templates/` files | **PASS** |
| **Directory Collision** | Deploy with an existing project name | Prompts overwrite confirmation; deletes safely if approved | **PASS** |
| **Deployment Option A** | Copy 5 students from template | `total_sessions` = 5, 5 students deployed, permissions set | **PASS** |
| **Deployment Option B** | Generate 4 students from scratch | `total_sessions` = 1, fresh students with 0 counts | **PASS** |
| **Threshold Sed Update** | Update warning: 80, failure: 60 | Validates numbers, `sed` edits `config.json` in place | **PASS** |
| **Invalid Threshold Input** | Input letters or failure > warning | Re-prompts with clear validation error message | **PASS** |
| **File Permissions** | Inspect with `ls -la` | `attendance_checker.py` is `rwxr-xr-x`, `config.json` is `rw-------` | **PASS** |
| **Feature 2 Execution** | Run marking session | Terminal accepts `P`/`A` inputs, updates roster and logs | **PASS** |
| **Feature 3 Archival** | Archive logs after session | Copies logs with timestamp into `archives/attendance/` and `archives/absent/` | **PASS** |
| **Missing Log Handling** | Archive when `absent.log` does not exist | Logs informative message without crashing | **PASS** |
| **Signal Trap (Ctrl+C)** | Interrupt deployment via Ctrl+C / SIGINT | Creates `.zip` recovery archive and removes incomplete folder | **PASS** |
| **Atomic Error Cleanup** | Input abort or permission failure | Bundles partial state into `.zip` and removes incomplete folder | **PASS** |

---

## Walkthrough Video Script & Demo Guide

When recording your demonstration video, follow this 4-step sequence to cover all rubric requirements:

1. **Introduction & Code Walkthrough (1 - 2 mins)**:
   - Introduce yourself: *"Hello, my name is Bethelhem Alemayehu Ejigu..."*
   - Briefly explain the principles of Infrastructure as Code (IaC) and automation.
   - Walk through the three main features in `deploy_agent.sh`:
     - Pre-flight checks (`python3 --version`, `zip`).
     - Scaffolding & roster generation (Option A vs Option B).
     - Permission hardening (`chmod +x` and `chmod 600`).
     - Threshold validation and `sed` editing.
     - Signal trap (`cleanup_on_interrupt` on `SIGINT` / `SIGTSTP`).

2. **Feature 1: Deployment & Verification Run (1 - 2 mins)**:
   - Run `./deploy_agent.sh deploy`.
   - Enter project name `v1`.
   - Select Option A (e.g. 5 students).
   - Customize thresholds (e.g. Warning: 80, Failure: 60).
   - Verify that Feature 2 automatically triggers to verify deployment.
   - Complete a short live marking session (mark students `P` or `A`).

3. **Feature 3: Log Archival (1 min)**:
   - Run `./deploy_agent.sh archive v1`.
   - Show the generated timestamped log files inside `attendance_tracker_v1/archives/`.
   - Explain how the script handles the edge case where no absences occurred.

4. **Signal Trap Interruption Demo (1 min)**:
   - Run `./deploy_agent.sh deploy`.
   - Enter project name `interrupt_demo`.
   - When prompted for the roster, press **`Ctrl + C`**.
   - Show that the interrupt was trapped cleanly:
     - `attendance_tracker_interrupt_demo_archive.zip` was created.
     - The incomplete folder `attendance_tracker_interrupt_demo` was deleted to avoid workspace clutter.
