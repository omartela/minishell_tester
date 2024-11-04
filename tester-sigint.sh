#!/bin/bash

# Path to your minishell executable
MINISHELL_PATH=".././minishell"
LOGFILE="signal_test_log.txt"

# Check if minishell exists and is executable
if [ ! -x "$MINISHELL_PATH" ]; then
    echo "Minishell executable not found or not executable at $MINISHELL_PATH"
    exit 1
fi

# Base directory for command files
COMMANDS_DIR="./signals/"

# Check if the command directory exists
if [ ! -d "$COMMANDS_DIR" ]; then
    echo "Command directory not found at $COMMANDS_DIR"
    exit 1
fi

# Clear or create the logfile
echo "Signal Test Log for $(date)" > "$LOGFILE"
echo "=============================" >> "$LOGFILE"

# Loop through each file in the command directory
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

        # Store command input
        INPUT="$line"

        # Temporary files for outputs and errors
        MINISHELL_OUTPUT=$(mktemp)
        MINISHELL_ERR=$(mktemp)
        BASH_OUTPUT=$(mktemp)
        BASH_ERR=$(mktemp)

        PIPE=$(mktemp -u)
        mkfifo $PIPE
        exec 3<>$PIPE
        rm $PIPE

        # Start minishell in background, run command, and send SIGTERM
        <&3 "$MINISHELL_PATH" >"$MINISHELL_OUTPUT" 2>&1 & #2>"$MINISHELL_ERR" &
        MINISHELL_PID=$!
        echo -n "$INPUT" >&3
        sleep 0.1  # Allow command to start
        kill -SIGINT "$MINISHELL_PID"
        sleep 0.1  # Allow command to start
        echo "exit" >&3
        wait "$MINISHELL_PID"

        PIPE=$(mktemp -u)
        mkfifo $PIPE
        exec 3<>$PIPE
        rm $PIPE
        # Start Bash in background, run command, and send SIGTERM
        <&3 bash >"$BASH_OUTPUT" 2>&1 & #2>"$BASH_ERR" &
        BASH_PID=$!
        echo -n "$INPUT" >&3
        sleep 0.1  # Allow command to start
        kill -SIGINT "$BASH_PID"
        sleep 0.1  # Allow command to start
        echo "exit" >&3
        kill -TERM "$BASH_PID"
        wait "$BASH_PID"
        exec 3>&-

        # Compare standard output
        echo -ne "\033[1;34mSTD_OUT:\033[m "
        if ! diff -q "$MINISHELL_OUTPUT" "$BASH_OUTPUT" >/dev/null; then
            echo -ne "❌  "
            echo -e "STDOUT difference for command:\n$INPUT\n" >> "$LOGFILE"
            echo "Expected (Bash):" >> "$LOGFILE"
            cat "$BASH_OUTPUT" >> "$LOGFILE"
            echo -e "\nGot (Minishell):" >> "$LOGFILE"
            cat "$MINISHELL_OUTPUT" >> "$LOGFILE"
            echo -e "\n---\n" >> "$LOGFILE"
        else
            echo -ne "✅  "
        fi

		 # Strip the "bash: line X:" prefix in the Bash stderr output before comparison
        sed 's/^bash: line [0-9]\+: //' "$BASH_ERR" >"${BASH_ERR}_stripped"

        # Compare standard error
        echo -ne "\033[1;33mSTD_ERR:\033[m "
        if ! diff -q "$MINISHELL_ERR" "${BASH_ERR}_stripped" >/dev/null; then
            echo -ne "❌  "
            echo -e "STDERR difference for command:\n$INPUT\n" >> "$LOGFILE"
            echo "Expected (Bash):" >> "$LOGFILE"
            cat "${BASH_ERR}_stripped" >> "$LOGFILE"
            echo -e "\nGot (Minishell):" >> "$LOGFILE"
            cat "$MINISHELL_ERR" >> "$LOGFILE"
            echo -e "\n---\n" >> "$LOGFILE"
        else
            echo -ne "✅  "
        fi

        # Clean up temporary files
        rm "$MINISHELL_OUTPUT" "$MINISHELL_ERR" "$BASH_OUTPUT" "$BASH_ERR"

        # Print command
        echo -e "\033[0;35mCommand(s): $INPUT\033[m"

    done < "$COMMANDS_FILE"
done

# Summary Report
echo -e "\n\033[1;32mSignal Testing Complete\033[m"
echo "Failures logged to $LOGFILE"
