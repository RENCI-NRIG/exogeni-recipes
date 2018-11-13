#!/bin/bash

source /etc/sysconfig/ryu

echo "--- RYU_PID_FILE: ${RYU_PID_FILE}"
echo "--- OFP_TCP_LISTEN_PORT: ${OFP_TCP_LISTEN_PORT}"
echo "--- RYU_LOG_FILE: ${RYU_LOG_FILE}"
echo "--- RYU_REST: ${RYU_REST}"
echo "--- RYU_APP: ${RYU_APP}"


/usr/bin/ryu-manager --pid-file ${RYU_PID_FILE}                            --ofp-tcp-listen-port ${OFP_TCP_LISTEN_PORT}                            --log-file ${RYU_LOG_FILE}                            --app-lists ${RYU_REST}                            ${RYU_APP}

