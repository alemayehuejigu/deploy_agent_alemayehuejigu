#!/usr/bin/env python3
import csv
import json
import os
import sys
from datetime import datetime

CONFIG_PATH = os.path.join("Helpers", "config.json")
ASSETS_PATH = os.path.join("Helpers", "assets.csv")
REPORTS_DIR = "reports"
ATTENDANCE_LOG_PATH = os.path.join(REPORTS_DIR, "attendance.log")
ABSENT_LOG_PATH = os.path.join(REPORTS_DIR, "absent.log")

def load_config():
    if not os.path.exists(CONFIG_PATH):
        print(f"Error: Configuration file not found at {CONFIG_PATH}")
        sys.exit(1)
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def load_roster():
    if not os.path.exists(ASSETS_PATH):
        print(f"Error: Roster file not found at {ASSETS_PATH}")
        sys.exit(1)
    roster = []
    with open(ASSETS_PATH, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            roster.append(row)
    return roster

def save_roster(roster, fieldnames):
    with open(ASSETS_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(roster)

def main():
    print("=" * 50)
    print("      Student Attendance Tracker (Live Session)    ")
    print("=" * 50)

    config = load_config()
    warning_threshold = config.get("thresholds", {}).get("warning", 75)
    failure_threshold = config.get("thresholds", {}).get("failure", 50)
    total_sessions = config.get("total_sessions", 5)

    os.makedirs(REPORTS_DIR, exist_ok=True)
    roster = load_roster()

    if not roster:
        print("Roster is empty. Exiting.")
        sys.exit(0)

    fieldnames = list(roster[0].keys())
    present_list = []
    absent_list = []

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print(f"\nTotal sessions configured: {total_sessions}")
    print(f"Alert Thresholds -> Warning: {warning_threshold}%, Failure: {failure_threshold}%\n")

    for student in roster:
        name = student.get("Names", "Unknown")
        email = student.get("Email", "unknown@example.com")
        curr_p = int(student.get("Attendance Count", 0))
        curr_a = int(student.get("Absence Count", 0))

        while True:
            choice = input(f"Mark attendance for {name} ({email}) [P/A]: ").strip().upper()
            if choice in ["P", "A"]:
                break
            print("Invalid input. Please enter 'P' for Present or 'A' for Absent.")

        if choice == "P":
            student["Attendance Count"] = str(curr_p + 1)
            present_list.append((name, email, curr_p + 1))
        else:
            student["Absence Count"] = str(curr_a + 1)
            absent_list.append((name, email, curr_a + 1))

    save_roster(roster, fieldnames)

    # Write attendance.log if attendees exist
    if present_list:
        with open(ATTENDANCE_LOG_PATH, "a", encoding="utf-8") as f:
            f.write(f"--- Session: {timestamp} ---\n")
            for name, email, count in present_list:
                pct = (count / total_sessions) * 100
                f.write(f"PRESENT: {name} ({email}) - Total Present: {count}/{total_sessions} ({pct:.1f}%)\n")

    # Write absent.log if absentees exist
    if absent_list:
        with open(ABSENT_LOG_PATH, "a", encoding="utf-8") as f:
            f.write(f"--- Session: {timestamp} ---\n")
            for name, email, count in absent_list:
                att_count = int(next(s["Attendance Count"] for s in roster if s["Email"] == email))
                pct = (att_count / total_sessions) * 100
                status_alert = ""
                if pct < failure_threshold:
                    status_alert = f" [ALERT: FAILURE RISK < {failure_threshold}%]"
                elif pct < warning_threshold:
                    status_alert = f" [ALERT: WARNING < {warning_threshold}%]"
                f.write(f"ABSENT: {name} ({email}) - Current Attendance: {att_count}/{total_sessions} ({pct:.1f}%){status_alert}\n")

    print("\n" + "=" * 50)
    print("Session Complete!")
    print(f"Present: {len(present_list)}, Absent: {len(absent_list)}")
    if present_list:
        print(f"Logged present records to: {ATTENDANCE_LOG_PATH}")
    if absent_list:
        print(f"Logged absent records to: {ABSENT_LOG_PATH}")
    print(f"Updated roster saved to: {ASSETS_PATH}")
    print("=" * 50)

if __name__ == "__main__":
    main()
