#!/usr/bin/env bash
set -u

cd "$(dirname "$0")" || exit 1

if [ -t 1 ]; then
	CS_RESET="$(printf '\033[0m')"
	CS_DIM="$(printf '\033[90m')"
	CS_BLUE="$(printf '\033[96m')"
	CS_CYAN="$(printf '\033[36m')"
	CS_GREEN="$(printf '\033[92m')"
	CS_YELLOW="$(printf '\033[93m')"
	CS_RED="$(printf '\033[91m')"
else
	CS_RESET=""
	CS_DIM=""
	CS_BLUE=""
	CS_CYAN=""
	CS_GREEN=""
	CS_YELLOW=""
	CS_RED=""
fi

printf "\n"
printf "%b============================================================%b\n" "$CS_BLUE" "$CS_RESET"
printf "%b                c o o l s t a t s%b\n" "$CS_BLUE" "$CS_RESET"
printf "%b                Rising Gods Logs%b\n" "$CS_CYAN" "$CS_RESET"
printf "%b============================================================%b\n" "$CS_BLUE" "$CS_RESET"
printf "%bLinux / Bash launcher%b\n" "$CS_DIM" "$CS_RESET"
printf "\n"
printf "%bData-only updater for the Rising Gods addon family.%b\n" "$CS_GREEN" "$CS_RESET"
printf "%bTarget: coolstats_Data_RisingGods plus generated UWU shard folders.%b\n" "$CS_DIM" "$CS_RESET"
printf "%bNo admin rights, no credentials, no GitHub publishing.%b\n" "$CS_DIM" "$CS_RESET"
printf "%bIncludes duplicate-name safeguards for reused Rising Gods character names.%b\n" "$CS_DIM" "$CS_RESET"
printf "%bA confirmation screen will appear before live addon files are replaced.%b\n" "$CS_YELLOW" "$CS_RESET"
printf "\n"
printf "%bPreparing updater...%b\n" "$CS_BLUE" "$CS_RESET"

UPDATER_SCRIPT="./tools/update_rising_gods_live_logs.py"
if [ ! -f "$UPDATER_SCRIPT" ]; then
	UPDATER_SCRIPT="./coolstats_LogUpdater/tools/update_rising_gods_live_logs.py"
fi
if [ ! -f "$UPDATER_SCRIPT" ]; then
	printf "\n"
	printf "%bUpdate failed. Could not find update_rising_gods_live_logs.py.%b\n" "$CS_RED" "$CS_RESET"
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
			printf "%bUpdate failed. Python 3 was not found in PATH.%b\n" "$CS_RED" "$CS_RESET"
			printf "Install Python 3, or set COOLSTATS_PYTHON to the Python command.\n"
			EXIT_CODE=1
		fi
	fi

	if [ "${EXIT_CODE:-0}" -eq 0 ]; then
		if [ "$#" -gt 0 ]; then
			"$PYTHON_CMD" "$UPDATER_SCRIPT" "$@"
			EXIT_CODE=$?
		elif [ -f "./coolstats/coolstats.toc" ] && [ -f "./coolstats_Data_RisingGods/coolstats_Data_RisingGods.toc" ] && [ -f "./coolstats_LogUpdater/tools/update_rising_gods_live_logs.py" ]; then
			printf "%bRelease install detected. The current folder will be used as Interface/AddOns.%b\n" "$CS_GREEN" "$CS_RESET"
			printf "\n"
			"$PYTHON_CMD" "$UPDATER_SCRIPT"
			EXIT_CODE=$?
		else
			printf "\n"
			printf "%bChoose update mode:%b\n" "$CS_BLUE" "$CS_RESET"
			printf "  %b1.%b Preview UI and validate current generated data\n" "$CS_YELLOW" "$CS_RESET"
			printf "  %b2.%b Update this working folder only, no live WoW install\n" "$CS_YELLOW" "$CS_RESET"
			printf "  %b3.%b Update and install to a live WoW Interface/AddOns folder\n" "$CS_YELLOW" "$CS_RESET"
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
					printf "%bInvalid choice. Nothing was changed.%b\n" "$CS_RED" "$CS_RESET"
					EXIT_CODE=1
					;;
			esac
		fi
	fi
fi

printf "\n"
if [ "${EXIT_CODE:-1}" -ne 0 ]; then
	printf "%bUpdate failed. The live addon is left on the last valid installed data when possible.%b\n" "$CS_RED" "$CS_RESET"
else
	printf "%bUpdate complete. Reload World of Warcraft if it is currently running.%b\n" "$CS_GREEN" "$CS_RESET"
fi
printf "\n"

if [ -t 0 ]; then
	printf "Press Enter to close..."
	read -r _
fi

exit "${EXIT_CODE:-1}"
