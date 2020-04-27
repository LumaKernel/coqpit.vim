#!/bin/bash

# This script is for local debugging
# Please feel free to edit and use this

PATH=~/.local/bin/coq/V8.11.1/bin:$PATH
themis --version

export THEMIS_VIM="vim"
export THEMIS_LOG_FILE="coqpit-vim.log"
themis "$@"

export THEMIS_VIM="nvim"
export THEMIS_ARGS="-e -s --headless"
export THEMIS_LOG_FILE="coqpit-nvim.log"
themis "$@"
