#!/bin/bash

# Advanced CLI Utility Script
# Source this file in your bash scripts to get powerful argument parsing capabilities
# Usage: source ~/cli.sh

# Global variables for the CLI utility
declare -A CLI_OPTIONS
declare -A CLI_OPTION_TYPES
declare -A CLI_OPTION_DESCRIPTIONS
declare -A CLI_OPTION_DEFAULTS
declare -A CLI_OPTION_REQUIRED
declare -A CLI_SHORT_TO_LONG
declare -a CLI_POSITIONAL_ARGS
declare CLI_SCRIPT_NAME=""
declare CLI_SCRIPT_DESCRIPTION=""
declare CLI_HELP_SHOWN=false

# Initialize CLI utility
cli_init() {
    CLI_SCRIPT_NAME="${1:-$(basename "$0")}"
    CLI_SCRIPT_DESCRIPTION="${2:-}"
    
    # Clear all arrays
    CLI_OPTIONS=()
    CLI_OPTION_TYPES=()
    CLI_OPTION_DESCRIPTIONS=()
    CLI_OPTION_DEFAULTS=()
    CLI_OPTION_REQUIRED=()
    CLI_SHORT_TO_LONG=()
    CLI_POSITIONAL_ARGS=()
    CLI_HELP_SHOWN=false
}

# Add an option definition
# Usage: cli_add_option "long_name" "short_name" "type" "description" "default_value" "required"
# Types: flag, string, int, float, file, dir
cli_add_option() {
    local long_name="$1"
    local short_name="$2"
    local type="${3:-flag}"
    local description="$4"
    local default_value="$5"
    local required="${6:-false}"
    
    if [[ -z "$long_name" ]]; then
        echo "Error: Long name is required" >&2
        return 1
    fi
    
    CLI_OPTION_TYPES["$long_name"]="$type"
    CLI_OPTION_DESCRIPTIONS["$long_name"]="$description"
    CLI_OPTION_DEFAULTS["$long_name"]="$default_value"
    CLI_OPTION_REQUIRED["$long_name"]="$required"
    
    # Set default value
    if [[ "$type" == "flag" ]]; then
        CLI_OPTIONS["$long_name"]="false"
    else
        CLI_OPTIONS["$long_name"]="$default_value"
    fi
    
    # Map short name to long name if provided
    if [[ -n "$short_name" ]]; then
        CLI_SHORT_TO_LONG["$short_name"]="$long_name"
    fi
}

# Validate option value based on type
cli_validate_value() {
    local type="$1"
    local value="$2"
    local name="$3"
    
    case "$type" in
        "flag")
            return 0
            ;;
        "string")
            if [[ -z "$value" ]]; then
                echo "Error: Option --$name requires a non-empty string value" >&2
                return 1
            fi
            ;;
        "int")
            if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
                echo "Error: Option --$name requires an integer value, got: $value" >&2
                return 1
            fi
            ;;
        "float")
            if ! [[ "$value" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
                echo "Error: Option --$name requires a numeric value, got: $value" >&2
                return 1
            fi
            ;;
        "file")
            if [[ -n "$value" && ! -f "$value" ]]; then
                echo "Error: Option --$name requires an existing file, got: $value" >&2
                return 1
            fi
            ;;
        "dir")
            if [[ -n "$value" && ! -d "$value" ]]; then
                echo "Error: Option --$name requires an existing directory, got: $value" >&2
                return 1
            fi
            ;;
        *)
            echo "Error: Unknown option type: $type" >&2
            return 1
            ;;
    esac
    
    return 0
}

# Get option value
# Usage: cli_get "option_name"
cli_get() {
    local name="$1"
    echo "${CLI_OPTIONS[$name]:-}"
}

# Check if flag is set
# Usage: cli_flag "flag_name"
cli_flag() {
    local name="$1"
    [[ "${CLI_OPTIONS[$name]:-false}" == "true" ]]
}

# Get positional arguments
# Usage: cli_args (returns all) or cli_args N (returns Nth argument, 1-indexed)
cli_args() {
    if [[ $# -eq 0 ]]; then
        printf '%s\n' "${CLI_POSITIONAL_ARGS[@]}"
    else
        local index=$(($1 - 1))
        if [[ $index -ge 0 && $index -lt ${#CLI_POSITIONAL_ARGS[@]} ]]; then
            echo "${CLI_POSITIONAL_ARGS[$index]}"
        fi
    fi
}

# Get number of positional arguments
cli_argc() {
    echo "${#CLI_POSITIONAL_ARGS[@]}"
}

# Generate help text
cli_help() {
    echo "Usage: $CLI_SCRIPT_NAME [OPTIONS] [ARGUMENTS]"
    
    if [[ -n "$CLI_SCRIPT_DESCRIPTION" ]]; then
        echo
        echo "$CLI_SCRIPT_DESCRIPTION"
    fi
    
    if [[ ${#CLI_OPTIONS[@]} -gt 0 ]]; then
        echo
        echo "Options:"
        
        # Find the longest option name for formatting
        local max_width=0
        for long_name in "${!CLI_OPTIONS[@]}"; do
            local short_name=""
            for short in "${!CLI_SHORT_TO_LONG[@]}"; do
                if [[ "${CLI_SHORT_TO_LONG[$short]}" == "$long_name" ]]; then
                    short_name="$short"
                    break
                fi
            done
            
            local opt_text="--$long_name"
            if [[ -n "$short_name" ]]; then
                opt_text="-$short_name, --$long_name"
            fi
            
            local type="${CLI_OPTION_TYPES[$long_name]}"
            if [[ "$type" != "flag" ]]; then
                opt_text="$opt_text <$type>"
            fi
            
            if [[ ${#opt_text} -gt $max_width ]]; then
                max_width=${#opt_text}
            fi
        done
        
        # Print options with descriptions
        for long_name in $(printf '%s\n' "${!CLI_OPTIONS[@]}" | sort); do
            local short_name=""
            for short in "${!CLI_SHORT_TO_LONG[@]}"; do
                if [[ "${CLI_SHORT_TO_LONG[$short]}" == "$long_name" ]]; then
                    short_name="$short"
                    break
                fi
            done
            
            local opt_text="--$long_name"
            if [[ -n "$short_name" ]]; then
                opt_text="-$short_name, --$long_name"
            fi
            
            local type="${CLI_OPTION_TYPES[$long_name]}"
            if [[ "$type" != "flag" ]]; then
                opt_text="$opt_text <$type>"
            fi
            
            local description="${CLI_OPTION_DESCRIPTIONS[$long_name]}"
            local default="${CLI_OPTION_DEFAULTS[$long_name]}"
            local required="${CLI_OPTION_REQUIRED[$long_name]}"
            
            printf "  %-${max_width}s  %s" "$opt_text" "$description"
            
            if [[ "$required" == "true" ]]; then
                printf " (required)"
            elif [[ -n "$default" && "$type" != "flag" ]]; then
                printf " (default: %s)" "$default"
            fi
            
            echo
        done
    fi
    
    echo
    echo "  -h, --help                Show this help message and exit"
}

# Parse command line arguments
# Usage: cli_parse "$@"
cli_parse() {
    CLI_POSITIONAL_ARGS=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cli_help
                CLI_HELP_SHOWN=true
                return 0
                ;;
            --*=*)
                # Long option with equals sign
                local arg="${1#--}"
                local name="${arg%%=*}"
                local value="${arg#*=}"
                
                if [[ -z "${CLI_OPTION_TYPES[$name]:-}" ]]; then
                    echo "Error: Unknown option --$name" >&2
                    return 1
                fi
                
                local type="${CLI_OPTION_TYPES[$name]}"
                if [[ "$type" == "flag" ]]; then
                    echo "Error: Flag option --$name does not accept a value" >&2
                    return 1
                fi
                
                if ! cli_validate_value "$type" "$value" "$name"; then
                    return 1
                fi
                
                CLI_OPTIONS["$name"]="$value"
                shift
                ;;
            --*)
                # Long option
                local name="${1#--}"
                
                if [[ -z "${CLI_OPTION_TYPES[$name]:-}" ]]; then
                    echo "Error: Unknown option --$name" >&2
                    return 1
                fi
                
                local type="${CLI_OPTION_TYPES[$name]}"
                if [[ "$type" == "flag" ]]; then
                    CLI_OPTIONS["$name"]="true"
                    shift
                else
                    if [[ $# -lt 2 ]]; then
                        echo "Error: Option --$name requires a value" >&2
                        return 1
                    fi
                    
                    local value="$2"
                    if ! cli_validate_value "$type" "$value" "$name"; then
                        return 1
                    fi
                    
                    CLI_OPTIONS["$name"]="$value"
                    shift 2
                fi
                ;;
            -*)
                # Short options (can be combined for flags)
                local short_opts="${1#-}"
                shift
                
                while [[ -n "$short_opts" ]]; do
                    local short_name="${short_opts:0:1}"
                    short_opts="${short_opts:1}"
                    
                    local long_name="${CLI_SHORT_TO_LONG[$short_name]:-}"
                    if [[ -z "$long_name" ]]; then
                        echo "Error: Unknown option -$short_name" >&2
                        return 1
                    fi
                    
                    local type="${CLI_OPTION_TYPES[$long_name]}"
                    if [[ "$type" == "flag" ]]; then
                        CLI_OPTIONS["$long_name"]="true"
                    else
                        if [[ -n "$short_opts" ]]; then
                            # Value is the rest of the short options string
                            local value="$short_opts"
                            short_opts=""
                        elif [[ $# -gt 0 ]]; then
                            # Value is the next argument
                            local value="$1"
                            shift
                        else
                            echo "Error: Option -$short_name requires a value" >&2
                            return 1
                        fi
                        
                        if ! cli_validate_value "$type" "$value" "$long_name"; then
                            return 1
                        fi
                        
                        CLI_OPTIONS["$long_name"]="$value"
                    fi
                done
                ;;
            *)
                # Positional argument
                CLI_POSITIONAL_ARGS+=("$1")
                shift
                ;;
        esac
    done
    
    # Check required options
    for long_name in "${!CLI_OPTION_REQUIRED[@]}"; do
        if [[ "${CLI_OPTION_REQUIRED[$long_name]}" == "true" ]]; then
            local type="${CLI_OPTION_TYPES[$long_name]}"
            local value="${CLI_OPTIONS[$long_name]}"
            
            if [[ "$type" == "flag" && "$value" != "true" ]] || [[ "$type" != "flag" && -z "$value" ]]; then
                echo "Error: Required option --$long_name is missing" >&2
                return 1
            fi
        fi
    done
    
    return 0
}

# Check if help was shown (useful for early exit)
cli_help_shown() {
    [[ "$CLI_HELP_SHOWN" == "true" ]]
}

# Convenience function to set up common options
cli_add_common_options() {
    cli_add_option "verbose" "v" "flag" "Enable verbose output"
    cli_add_option "quiet" "q" "flag" "Suppress output"
    cli_add_option "config" "c" "file" "Configuration file path"
    cli_add_option "output" "o" "string" "Output file or directory"
}

# Debug function to show all parsed options and arguments
cli_debug() {
    echo "=== CLI Debug Information ==="
    echo "Script: $CLI_SCRIPT_NAME"
    echo "Description: $CLI_SCRIPT_DESCRIPTION"
    echo
    echo "Options:"
    for name in $(printf '%s\n' "${!CLI_OPTIONS[@]}" | sort); do
        printf "  %-15s = %s\n" "$name" "${CLI_OPTIONS[$name]}"
    done
    echo
    echo "Positional Arguments (${#CLI_POSITIONAL_ARGS[@]}):"
    for i in "${!CLI_POSITIONAL_ARGS[@]}"; do
        printf "  [%d] = %s\n" "$((i+1))" "${CLI_POSITIONAL_ARGS[$i]}"
    done
    echo "=========================="
}

# Example usage:
# ./backup.sh --source /path/to/source --dest /path/to/destination --exclude "*.log"

# cli_init "backup" "File backup utility"

# cli_add_option "source" "s" "dir" "Source directory" "" "true"
# cli_add_option "dest" "d" "dir" "Destination directory" "" "true"  
# cli_add_option "verbose" "v" "flag" "Verbose output"
# cli_add_option "exclude" "e" "string" "Pattern to exclude"

# if ! cli_parse "$@"; then exit 1; fi
# if cli_help_shown; then exit 0; fi

# echo "Backing up $(cli_get source) to $(cli_get dest)"
# if cli_flag verbose; then
#     echo "Verbose mode enabled"
# fi