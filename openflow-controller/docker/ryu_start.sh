#!/bin/bash

RYU_DIR="/opt/ryu"
RYU_REST_APP="ofctl_rest.py"
RYU_PID_FILE="/var/run/ryu/ryu-manager.pid"
RYU_LOG_FILE="/var/log/ryu/ryu-manager.log"
RYU_CONFIG_DIR="/opt/ryu/etc"
RYU_APP="/opt/simple_switch_13_custom_chameleon.py"
RYU_REST="/opt/ofctl_rest.py"
OFP_TCP_LISTEN_PORT="6653"

/usr/bin/ryu-manager --pid-file ${RYU_PID_FILE} --ofp-tcp-listen-port ${OFP_TCP_LISTEN_PORT} --log-file ${RYU_LOG_FILE} --app-lists ${RYU_REST} ${RYU_APP}

