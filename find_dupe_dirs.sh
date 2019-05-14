#!/usr/bin/env bash

## Declare $dirs and $count as associative arrays
declare -A dirs
declare -A count

find_dirs(){
    ## Make ** recurse into subdirectories
    shopt -s globstar
    for d in "$1"/**
    do
    ## Remove the top directory from the dir's path
    dd="${d#*/}"
    ## If this is a directory, and is not the top directory
    if [[ -d "$d" && "$dd" != "" ]]
    then
        ## Count the number of times it's been seen
        let count["$dd"]++
        ## Add it to the list of paths with that name.
        ## I am using the `&` to separate directory entries
        dirs["$dd"]="${dirs[$dd]} & $d" 
    fi

    done
}

## Iterate over the list of paths given as arguments
for target in "$@"
do
    ## Run the find_dirs function on each of them
    find_dirs "$target"
done

## For each directory found by find_dirs
for d in "${!dirs[@]}"
do
    ## If this name has been seen more than once
    if [[ ${count["$d"]} > 1 ]]
    then
    ## Print the name with pretty colors
    printf '\033[01;31m+++ NAME: "%s" +++\033[00m\n' "$d"
    ## Print the paths with that name
    printf "%s\n" "${dirs[$d]}" | sed 's/^ & //'
    fi
done
