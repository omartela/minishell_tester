#!/bin/bash

# Path to your minishell executable
MINISHELL_PATH="../minishell/./minishell"

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

        # Run the command in bash and capture the output, error, and exit code
        echo -n "$INPUT" | bash >"$BASH_OUTPUT" 2>"$BASH_ERR"
        BASH_EXIT_CODE=$?

        # Compare standard output
        echo -ne "\033[1;34mSTD_OUT:\033[m "
        if ! diff -q "$MINISHELL_OUTPUT" "$BASH_OUTPUT" >/dev/null; then
            echo -ne "❌  "
            ((TEST_KO_OUT++))
            ((FAILED++))
        else
            echo -ne "✅  "
            ((TEST_OK++))
        fi

        # Compare standard error, checking for empty output specifically
        echo -ne "\033[1;33mSTD_ERR:\033[m "
        if [[ -s "$MINISHELL_ERR" && ! -s "$BASH_ERR" ]] || [[ ! -s "$MINISHELL_ERR" && -s "$BASH_ERR" ]]; then
            echo -ne "❌  "
            ((TEST_KO_ERR++))
            ((FAILED++))
        elif ! diff -q "$MINISHELL_ERR" "$BASH_ERR" >/dev/null; then
            echo -ne "❌  "
            ((TEST_KO_ERR++))
            ((FAILED++))
        else
            echo -ne "✅  "
            ((TEST_OK++))
        fi

        # Compare exit codes
        echo -ne "\033[1;36mEXIT_CODE:\033[m "
        if [[ $MINISHELL_EXIT_CODE -ne $BASH_EXIT_CODE ]]; then
            echo -ne "❌ \033[1;31m[minishell($MINISHELL_EXIT_CODE) bash($BASH_EXIT_CODE)]\033[m  "
            ((TEST_KO_EXIT++))
            ((FAILED++))
        else
            echo -ne "✅  "
            ((TEST_OK++))
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
