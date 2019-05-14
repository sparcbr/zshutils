#!/bin/bash

# Usage:
# Source this script
# enable_trapping <- optional to clean up properly if user presses ctrl-c
# setup_scroll_area <- create empty progress bar
# draw_progress_bar 10 <- advance progress bar
# draw_progress_bar 40 <- advance progress bar
# block_progress_bar 45 <- turns the progress bar yellow to indicate some action is requested from the user
# draw_progress_bar 90 <- advance progress bar
# destroy_scroll_area <- remove progress bar


# Constants
CODE_SAVE_CURSOR="\033[s"
CODE_RESTORE_CURSOR="\033[u"
CODE_CURSOR_IN_SCROLL_AREA="\033[1A"
COLOR_FG="\e[30m"
COLOR_BG="\e[42m"
COLOR_BG_BLOCKED="\e[43m"
RESTORE_FG="\e[39m"
RESTORE_BG="\e[49m"

function init_vars() {
	# Variables
	PROGRESS_BLOCKED="false"
	TRAPPING_ENABLED="false"
	TRAP_SET="false"
	PBAR_CHAR=""
}

function setup_scroll_area() {
	init_vars
	#[[ -n "$1" ]] && PBAR_CHAR=${1[1]}
    # If trapping is enabled, we will want to activate it whenever we setup the scroll area and remove it when we break the scroll area
    if [ "$TRAPPING_ENABLED" = "true" ]; then
        trap_on_interrupt
    fi

    lines=$(tput lines)
    let lines=$lines-1
    # Scroll down a bit to avoid visual glitch when the screen area shrinks by one row
    echo -en "\n"

    # Save cursor
    echo -en "$CODE_SAVE_CURSOR"
    # Set scroll region (this will place the cursor in the top left)
    echo -en "\033[0;${lines}r"

    # Restore cursor but ensure its inside the scrolling area
    echo -en "$CODE_RESTORE_CURSOR"
    echo -en "$CODE_CURSOR_IN_SCROLL_AREA"

    # Start empty progress bar
    draw_progress_bar 0
}

function destroy_scroll_area() {
    lines=$(tput lines)
    # Save cursor
    echo -en "$CODE_SAVE_CURSOR"
    # Set scroll region (this will place the cursor in the top left)
    echo -en "\033[0;${lines}r"

    # Restore cursor but ensure its inside the scrolling area
    echo -en "$CODE_RESTORE_CURSOR"
    echo -en "$CODE_CURSOR_IN_SCROLL_AREA"

    # We are done so clear the scroll bar
    clear_progress_bar

    # Scroll down a bit to avoid visual glitch when the screen area grows by one row
    echo -en "\n\n"
    
    # Once the scroll area is cleared, we want to remove any trap previously set. Otherwise, ctrl+c will exit our shell
    if [ "$TRAP_SET" = "true" ]; then
        trap - INT
    fi
}

function draw_progress_bar() {
    percentage=$1
    lines=$(tput lines)
    let lines=$lines
    # Save cursor
    echo -en "$CODE_SAVE_CURSOR"

    # Move cursor position to last row
    echo -en "\033[${lines};0f"

    # Clear progress bar
    tput el

    # Draw progress bar
    PROGRESS_BLOCKED="false"
    print_bar_text $percentage

    # Restore cursor position
    echo -en "$CODE_RESTORE_CURSOR"
}

function block_progress_bar() {
    percentage=$1
    lines=$(tput lines)
    let lines=$lines
    # Save cursor
    echo -en "$CODE_SAVE_CURSOR"

    # Move cursor position to last row
    echo -en "\033[${lines};0f"

    # Clear progress bar
    tput el

    # Draw progress bar
    PROGRESS_BLOCKED="true"
    print_bar_text $percentage

    # Restore cursor position
    echo -en "$CODE_RESTORE_CURSOR"
}

function clear_progress_bar() {
    lines=$(tput lines)
    let lines=$lines
    # Save cursor
    echo -en "$CODE_SAVE_CURSOR"

    # Move cursor position to last row
    echo -en "\033[${lines};0f"

    # clear progress bar
    tput el

    # Restore cursor position
    echo -en "$CODE_RESTORE_CURSOR"
}

function print_bar_text() {
    local percentage=$1
    local cols=$(tput cols)
    let bar_size=$cols-17

    local color="${COLOR_FG}${COLOR_BG}"
    if [ "$PROGRESS_BLOCKED" = "true" ]; then
        color="${COLOR_FG}${COLOR_BG_BLOCKED}"
    fi

    # Prepare progress bar
    let complete_size=($bar_size*$percentage)/100
    let remainder_size=$bar_size-$complete_size
    progress_bar=$(echo -ne "["; echo -en "${color}"; printf_new "$PBAR_CHAR" $complete_size; echo -en "${RESTORE_FG}${RESTORE_BG}"; printf_new "." $remainder_size; echo -ne "]");

    # Print progress bar
    echo -ne " Progress ${percentage}% ${progress_bar}"
}

function disable_trapping() {
    TRAPPING_ENABLED="false"
}
function enable_trapping() {
    TRAPPING_ENABLED="true"
}

function trap_on_interrupt() {
    # If this function is called, we setup an interrupt handler to cleanup the progress bar
    TRAP_SET="true"
    trap cleanup_on_interrupt INT
}

function cleanup_on_interrupt() {
    destroy_scroll_area
    exit
}

function printf_new() {
    str=$1
    num=$2
    v=$(printf "%-${num}s" "$str")
    echo -ne "${v// /$str}"
}
