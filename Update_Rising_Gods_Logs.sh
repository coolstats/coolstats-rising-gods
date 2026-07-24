#!/usr/bin/env bash
set -u

cd "$(dirname "$0")" || exit 1

printf "\n"
printf "coolstats Rising Gods log updater\n"
printf "---------------------------------\n"
printf "Linux / Bash launcher\n"
printf "This updates only the Rising Gods data addon: coolstats_Data_RisingGods\n"
printf "A confirmation screen will appear before any live addon files are replaced.\n"
printf "\n"
printf "Preparing updater...\n"

UPDATER_SCRIPT="./tools/update_rising_gods_live_logs.py"
if [ ! -f "$UPDATER_SCRIPT" ]; then
	UPDATER_SCRIPT="./coolstats_LogUpdater/tools/update_rising_gods_live_logs.py"
fi
if [ ! -f "$UPDATER_SCRIPT" ]; then
	printf "\n"
	printf "Update failed. Could not find update_rising_gods_live_logs.py.\n"
	EXIT_CODE=1
else
	PYTHON_CMD="${COOLSTATS_PYTHON:-}"
	if [ -z "$PYTHON_CMD" ]; then
		if command -v python3 >/dev/null 2>&1; then
			PYTHON_CMD="python3"
		elif command -v python >/dev/null 2>&1; then
			PYTHON_CMD="python"
		else
			printf "\n"
			printf "Update failed. Python 3 was not found in PATH.\n"
			printf "Install Python 3, or set COOLSTATS_PYTHON to the Python command.\n"
			EXIT_CODE=1
		fi
	fi

	if [ "${EXIT_CODE:-0}" -eq 0 ]; then
		if [ "$#" -gt 0 ]; then
			"$PYTHON_CMD" "$UPDATER_SCRIPT" "$@"
			EXIT_CODE=$?
		elif [ -f "./coolstats/coolstats.toc" ] && [ -f "./coolstats_Data_RisingGods/coolstats_Data_RisingGods.toc" ] && [ -f "./coolstats_LogUpdater/tools/update_rising_gods_live_logs.py" ]; then
			printf "Release install detected. The current folder will be used as Interface/AddOns.\n"
			printf "\n"
			"$PYTHON_CMD" "$UPDATER_SCRIPT"
			EXIT_CODE=$?
		else
			printf "\n"
			printf "Choose update mode:\n"
			printf "  1. Preview UI and validate current generated data\n"
			printf "  2. Update this working folder only, no live WoW install\n"
			printf "  3. Update and install to a live WoW Interface/AddOns folder\n"
			printf "\n"
			printf "Type 1, 2, or 3 and press Enter: "
			read -r UPDATE_MODE

			case "$UPDATE_MODE" in
				1)
					"$PYTHON_CMD" "$UPDATER_SCRIPT" --validate-only
					EXIT_CODE=$?
					;;
				2)
					"$PYTHON_CMD" "$UPDATER_SCRIPT" --no-install
					EXIT_CODE=$?
					;;
				3)
					"$PYTHON_CMD" "$UPDATER_SCRIPT"
					EXIT_CODE=$?
					;;
				*)
					printf "\n"
					printf "Invalid choice. Nothing was changed.\n"
					EXIT_CODE=1
					;;
			esac
		fi
	fi
fi

printf "\n"
if [ "${EXIT_CODE:-1}" -ne 0 ]; then
	printf "Update failed. The live addon is left on the last valid installed data when possible.\n"
else
	printf "Update complete. Reload World of Warcraft if it is currently running.\n"
fi
printf "\n"

if [ -t 0 ]; then
	printf "Press Enter to close..."
	read -r _
fi

exit "${EXIT_CODE:-1}"
