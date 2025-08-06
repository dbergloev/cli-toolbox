#!/bin/bash
#
# Cleanup old docker images that no longer refers to any existing containers
#

/usr/bin/docker image prune -af

