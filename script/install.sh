#!/bin/bash

set -euo pipefail

./script/bootstrap.sh
./script/start.sh
./script/configure.sh

echo "ℹ Actions Runner Controller is now installed!"
echo "The following workflow file can be used in order to test it out:"

./script/subst.sh ./data/workflow.yml
