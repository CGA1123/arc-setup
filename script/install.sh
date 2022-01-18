#!/bin/bash

set -euo pipefail

./script/bootstrap.sh
./script/start.sh
./script/configure.sh

echo
echo
echo "ℹ Actions Runner Controller is now installed!"
echo "ℹ The following workflow file can be used in order to test it out:"
echo
echo

./script/subst.sh ./data/workflow.yml

echo
echo
