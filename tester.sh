#!/bin/bash

# Path to your minishell executable
MINISHELL_PATH=".././minishell"
LOGFILE="$(pwd)/error_log.txt"

# Check if minishell exists and is executable
if [ ! -x "$MINISHELL_PATH" ]; then
    echo "Minishell executable not found or not executable at $MINISHELL_PATH"
    exit 1
fi

# Base directory for command files
COMMANDS_DIR=./tests

# Check if the command directory exists
if [ ! -d "$COMMANDS_DIR" ]; then
    echo "Command directory not found at $COMMANDS_DIR"
    exit 1
fi

# Track commands with output, exit code, or both differences
DIFFERENT_COMMANDS=()

# Clear or create the logfile
echo "Failure Log for $(date)" > "$LOGFILE"
echo "=============================" >> "$LOGFILE"

PROMPT=$(echo -e "\nexit\n" | $MINISHELL_PATH 2>/dev/null | head -n 1 | sed "s/\x1B\[[0-9;]\{1,\}[A-Za-z]//g" )
# Loop through each file in the cmds/mand directory
for COMMANDS_FILE in "$COMMANDS_DIR"/*; do
    # Check if the file is readable
    if [ ! -f "$COMMANDS_FILE" ] || [ ! -r "$COMMANDS_FILE" ]; then
        echo "Cannot read file $COMMANDS_FILE, skipping..."
        continue
    fi

    echo -e "\033[1;31mProcessing file\033[0m: $COMMANDS_FILE"

    # Read each command from the current file and execute it
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Capture multi-line commands as a single block
        INPUT=""
        while [[ -n "$line" && ! "$line" =~ ^# ]]; do
            INPUT+="$line"$'\n'
            read -r line || break
        done

        # Create temporary files for storing outputs and errors
        MINISHELL_OUTPUT=$(mktemp)
        MINISHELL_ERR=$(mktemp)
        BASH_OUTPUT=$(mktemp)
        BASH_ERR=$(mktemp)

        # Run the command in minishell and capture the output, error, and exit code
        echo -n "$INPUT" | "$MINISHELL_PATH" >"$MINISHELL_OUTPUT" 2>"$MINISHELL_ERR"
        MINISHELL_EXIT_CODE=$?

        # Filter out the prompt from MINISHELL_OUTPUT
        grep -vF "$PROMPT" "$MINISHELL_OUTPUT" > "${MINISHELL_OUTPUT}_filtered"
        mv "${MINISHELL_OUTPUT}_filtered" "$MINISHELL_OUTPUT"

        # Run the command in bash and capture the output, error, and exit code
        echo -n "$INPUT" | bash >"$BASH_OUTPUT" 2>"$BASH_ERR"
        BASH_EXIT_CODE=$?

        FAILED_TEST=0

        # Compare standard output
        echo -ne "\033[1;34mSTD_OUT:\033[m "
        if ! diff -q "$MINISHELL_OUTPUT" "$BASH_OUTPUT" >/dev/null; then
            echo -ne "❌  "
            ((FAILED++))
            FAILED_TEST=1
            echo -e "STDOUT difference for command:\n$INPUT\n" >> "$LOGFILE"
            echo "Expected (Bash):" >> "$LOGFILE"
            cat "$BASH_OUTPUT" >> "$LOGFILE"
            echo -e "\nGot (Minishell):" >> "$LOGFILE"
            cat "$MINISHELL_OUTPUT" >> "$LOGFILE"
            echo -e "\n---\n" >> "$LOGFILE"
        else
            echo -ne "✅  "
            ((TEST_OK++))
        fi

         # Strip the "bash: line X:" prefix in the Bash stderr output before comparison
        sed 's/^bash: line [0-9]\+: //' "$BASH_ERR" >"${BASH_ERR}_stripped"

        # Compare standard error
        echo -ne "\033[1;33mSTD_ERR:\033[m "
        if [[ -s "$MINISHELL_ERR" && ! -s "${BASH_ERR}_stripped" ]] || [[ ! -s "$MINISHELL_ERR" && -s "${BASH_ERR}_stripped" ]] || ! diff -q "$MINISHELL_ERR" "${BASH_ERR}_stripped" >/dev/null; then
            echo -ne "❌  "
            ((FAILED++))
            FAILED_TEST=1
            echo -e "STDERR difference for command:\n$INPUT\n" >> "$LOGFILE"
            echo "Expected (Bash):" >> "$LOGFILE"
            cat "${BASH_ERR}_stripped" >> "$LOGFILE"
            echo -e "\nGot (Minishell):" >> "$LOGFILE"
            cat "$MINISHELL_ERR" >> "$LOGFILE"
            echo -e "\n---\n" >> "$LOGFILE"
        else
            echo -ne "✅  "
            ((TEST_OK++))
        fi

        # Compare exit codes
        echo -ne "\033[1;36mEXIT_CODE:\033[m "
        if [[ $MINISHELL_EXIT_CODE -ne $BASH_EXIT_CODE ]]; then
            echo -ne "❌ \033[1;31m[minishell($MINISHELL_EXIT_CODE) bash($BASH_EXIT_CODE)]\033[m  "
            ((FAILED++))
            FAILED_TEST=1
            echo -e "EXIT CODE difference for command:\n$INPUT\nExpected: $BASH_EXIT_CODE, Got: $MINISHELL_EXIT_CODE\n" >> "$LOGFILE"
            echo -e "\n---\n" >> "$LOGFILE"
        else
            echo -ne "✅  "
            ((TEST_OK++))
        fi

        # Log the command if any test failed
        if (( FAILED_TEST )); then
            echo -e "Failed Command:\n$INPUT\n" >> "$LOGFILE"
            echo "=============================" >> "$LOGFILE"
        fi

        # Clean up temporary files
        rm "$MINISHELL_OUTPUT" "$MINISHELL_ERR" "$BASH_OUTPUT" "$BASH_ERR"

        # Print command
        echo -e "\033[0;35mCommand(s): $INPUT\033[m"

    done < "$COMMANDS_FILE"
done

# Summary Report
echo -e "\n\033[1;32mTesting Complete\033[m"
echo "Total Tests: $((TEST_OK + FAILED)) | Passed: $TEST_OK | Failed: $FAILED"
echo "Failures logged to $LOGFILE"
