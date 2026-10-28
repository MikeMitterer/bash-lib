# Basics zum Makefile:
#	https://makefiletutorial.com/#getting-started
#	https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html
#
# You can set these variables from the command line.
# BUILDDIR      = _build

.PHONY: help test share

.DEFAULT_GOAL := help

VERSION   := 0.1

# Mountpoint im Jenkins-Slave (VM)
SHARES	   := /mnt/shares/scripts

GITHUB_URL := $$(git config --get remote.origin.url || echo "Kein GH Project!")
WORKSPACE := $(realpath $(dir $(abspath $(firstword $(MAKEFILE_LIST)))))

SCRIPTS   := $(wildcard src/*)

# MakeLib ist optional: ohne DEV_MAKE gelten die Ersatzfarben darunter.
-include ${DEV_MAKE}/colours.mk

YELLOW ?= $(shell printf "\033[38;5;11m")
GREEN  ?= $(shell printf "\033[38;5;10m")
BLUE   ?= $(shell printf "\033[38;5;33m")
RESET  ?= $(shell printf "\033[0m")
NC     ?= $(shell printf "\033[0m")

# Include wird nur ausgeführt wenn das
# File auch vorhanden ist
# EXTRA_INCLUDES:=$(wildcard .config.*)
# ifneq ($(strip $(EXTRA_INCLUDES)),)
#   include $(EXTRA_INCLUDES)
# endif

SHARED_LIB := ${DEV_SHARED}/scripts/libs/bash

help:
	@echo
	@echo "Please use \`make <${YELLOW}target${RESET}>' where <target> is one of"
	@echo
	@echo "    ${YELLOW}help       ${GREEN}This help message${NC}"
	@echo
	@echo "    ${YELLOW}test       ${GREEN}Runs the commandline-tests from${NC} ./test/testAll.sh"
	@echo "    ${YELLOW}share      ${GREEN}Shares scripts/libs on:${NC} ${SHARED_LIB}"
	@echo
	@echo "${BLUE}Info:${NC}"
	@echo "     GH URL:         ${BLUE}${GITHUB_URL}${NC}"
	@echo
#	@echo "${BLUE}Hints:${NC}"
#	@echo "    Forces make to run the target unconditionally"
#	@echo "     - ${YELLOW}make -B deploy${NC}"
	@echo

test:
	./test/testAll.sh


_share_exist:
	@if [ ! -d "${SHARED_LIB}" ]; then \
	    mkdir -p ${SHARED_LIB}; \
	fi

# $^ - all dependencies
share: | _share_exist
	@for file in $(SCRIPTS) ; do \
		echo "    share ${BLUE}$${file}${NC} ->  ${YELLOW}${SHARED_LIB}${NC}"; \
		\cp $${file} ${SHARED_LIB}; \
	done

all: test share

