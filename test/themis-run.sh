#!/bin/bash
PATH=~/.local/bin/coq/V8.11.1/bin:$PATH
themis --version

export THEMIS_VIM="vim"
themis

export THEMIS_VIM="nvim"
export THEMIS_ARGS="-e -s --headless"
themis
