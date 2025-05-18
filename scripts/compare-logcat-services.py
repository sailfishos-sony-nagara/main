#!/usr/bin/env python

import argparse
import re
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict

# List of services to ignore when comparing
IGNORED_SERVICES = [
    # from android 
    'adbd', 'audioserver', 'bootanim', 'bpfloader', 'cameraserver', 'gpu', 'installd', 'lmkd', 
    'mediaextractor', 'mediametrics', 'netd', 'storaged', 'surfaceflinger', 'time_daemon', 
    'ueventd', 'update_engine', 'update_verifier', 'vendor.audio-hal', 'vendor.usb-hal-1-3', 
    'vendor.vibrator.cs40l25', 'vold', 'wificond', 'wpa_supplicant', 'zygote', 'zygote_secondary',

    # excluded in nagara
    'vendor.livedisplay-hal-2-1',

    # some commands in android
    '/system/bin/extra_free_kbytes.sh 32880',
    '/system/bin/vdc --wait cryptfs enablefilecrypto',
    '/system/bin/vdc --wait cryptfs init_user0',
    '/system/bin/vdc checkpoint markBootAttempt',
    '/system/bin/vdc checkpoint prepareCheckpoint',
    '/system/bin/vdc keymaster earlyBootEnded',
    '/vendor/bin/wait4tad', # <-- gives extra time to settle

    # from sfos
    'droid_init_done', 'minimedia', 'minisf'
    ]

TIME_FORMAT = "%m-%d %H:%M:%S.%f"
TIME_RE = re.compile(r"(\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}).*")
SERVICE_RE = re.compile(r"(\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}).*started service '([^']+)'")
EXEC_SERVICE_RE = re.compile(r"^exec \d+ \(([^)]+)\)$")

def normalize_service(service: str) -> str:
    match = EXEC_SERVICE_RE.match(service)
    if match:
        return match.group(1).strip()  # return the command inside the parentheses
    return service.strip()

def parse_logcat(path: Path):
    service_order = []
    service_times = {}
    dt = timedelta(0)
    t_prev = None
    with path.open() as f:
        for line in f:
            match_time = TIME_RE.search(line)
            if match_time:
                timestamp = match_time.groups()[0]
                t = datetime.strptime(timestamp, TIME_FORMAT)
                if t_prev is not None and t_prev > t + timedelta(1):
                    dt -= t - t_prev
                t_prev = t

            match = SERVICE_RE.search(line)
            if match:
                timestamp, service = match.groups()
                service = normalize_service(service)
                if service in IGNORED_SERVICES:
                    continue
                if service not in service_times:
                    service_order.append(service)
                    service_times[service] = datetime.strptime(timestamp, TIME_FORMAT) + dt
    return service_order, service_times

def build_dependency_map(service_order):
    dependencies = {}
    seen = set()
    for service in service_order:
        dependencies[service] = seen.copy()
        seen.add(service)
    return dependencies

def compare_services(android_services, sailfish_services):
    return set(android_services) - set(sailfish_services)

def diff_sets(a, b):
    return sorted(a - b)

def print_report(missing_services, reordered_services, android_times, sailfish_times, ref_service):
    print("=== Missing Services in Sailfish ===")
    for svc in sorted(missing_services):
        print(f"  {svc}")

    print("\n=== Services with Different Start Order ===")
    if ref_service not in android_times or ref_service not in sailfish_times:
        print(f"Reference service '{ref_service}' missing in logs. Skipping time delta analysis.")
        ref_android_time = ref_sailfish_time = None
    else:
        ref_android_time = android_times[ref_service]
        ref_sailfish_time = sailfish_times[ref_service]

    for svc, (a_deps, s_deps) in reordered_services.items():
        print(f"\nService: {svc}")
        only_in_android = diff_sets(a_deps, s_deps)
        only_in_sailfish = diff_sets(s_deps, a_deps)

        if only_in_android:
            print(f"  Android-only deps: {only_in_android}")
        if only_in_sailfish:
            print(f"  Sailfish-only deps: {only_in_sailfish}")

        # Time deltas
        if svc in android_times and svc in sailfish_times and ref_android_time and ref_sailfish_time:
            android_delta = (android_times[svc] - ref_android_time).total_seconds()
            sailfish_delta = (sailfish_times[svc] - ref_sailfish_time).total_seconds()
            print(f"  Android time since '{ref_service}':  {android_delta:.3f}s")
            print(f"  Sailfish time since '{ref_service}': {sailfish_delta:.3f}s")
        else:
            print("  Time delta: N/A")

def main():
    parser = argparse.ArgumentParser(description="Compare Android and Sailfish logcat service startups.")
    parser.add_argument("android_log", type=Path, help="Path to Android logcat file")
    parser.add_argument("sailfish_log", type=Path, help="Path to Sailfish logcat file")
    args = parser.parse_args()

    # Parse logs
    android_order, android_times = parse_logcat(args.android_log)
    sailfish_order, sailfish_times = parse_logcat(args.sailfish_log)

    # Compare missing
    missing_services = compare_services(android_order, sailfish_order)

    # Build dependencies
    android_deps = build_dependency_map(android_order)
    sailfish_deps = build_dependency_map(sailfish_order)

    # Compare dependency differences
    reordered_services = {}
    common_services = set(android_order) & set(sailfish_order)
    # Make a list and order by Android boot time
    common_ordered = []
    for svc in common_services:
        common_ordered.append([android_times[svc], svc])
    common_ordered.sort()
    for _, svc in common_ordered:
        a_deps, s_deps = android_deps.get(svc, set()), sailfish_deps.get(svc, set())
        if a_deps != s_deps:
            reordered_services[svc] = (a_deps, s_deps)

    # Print report
    print_report(missing_services, reordered_services, android_times, sailfish_times, ref_service='apexd-bootstrap')

if __name__ == "__main__":
    main()
