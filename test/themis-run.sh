#!/bin/bash
themis --version

export THEMIS_VIM="vim"
themis

export THEMIS_VIM="nvim"
export THEMIS_ARGS="-e -s --headless"
themis
