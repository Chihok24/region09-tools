#!/usr/bin/env bash
# Kept for compatibility: refreshes only the Alarm Exceptions app. See update-apps.sh.
exec "$(dirname "$0")/update-apps.sh" alarm "$@"
