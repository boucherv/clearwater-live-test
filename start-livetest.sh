#!/bin/bash

source /etc/profile.d/rvm.sh
cd /home/opnfv/repos/vnfs/vims-test/
bundle exec lib/daemon.rb run
