#!/bin/bash

set -u

NUM_CLIENTS=4
NUM_SERVERS=2
BRIDGE_NS=bridge_ns


function setup_veth {
    local NS=${1}_ns
    local REMOTE_ITF=$1
    local IP_ADDR_LOCAL=$2

    echo "Creating virtual tunnel veth0(${NS}) <-> ${REMOTE_ITF}(${BRIDGE_NS})"
    ip netns add $NS
    ip link add veth0 type veth peer name $REMOTE_ITF
    ip link set veth0 netns $NS
    ip link set $REMOTE_ITF netns $BRIDGE_NS

    ip netns exec $BRIDGE_NS ip link set dev $REMOTE_ITF master br0
    ip netns exec $BRIDGE_NS ip link set $REMOTE_ITF up

    echo "Assigning addr ${IP_ADDR_LOCAL} to veth0 in ${NS}"
    ip netns exec $NS ip addr add ${IP_ADDR_LOCAL}/24 dev veth0
    ip netns exec $NS ip link set veth0 up
}

case $1 in
up)
    ip netns add $BRIDGE_NS
    ip netns exec $BRIDGE_NS ip link add name br0 type bridge

    # configure clients
    for i in $(seq 0 $(($NUM_CLIENTS-1)) );
    do
        setup_veth client${i} "192.0.2.$((128 + $i))"
    done

    # configure servers
    for i in $(seq 0 $(($NUM_SERVERS-1)) );
    do
        setup_veth server${i} "192.0.2.$((2 + $i))"
    done

    # configure balancer0
    setup_veth balancer0 "192.0.2.1"

    ip netns exec $BRIDGE_NS ip link set br0 up
    ;;

down)
    for i in $(seq 0 $(($NUM_CLIENTS-1)) );
    do
        ip netns delete client${i}_ns
    done
    for i in $(seq 0 $(($NUM_SERVERS-1)) );
    do
        ip netns delete server${i}_ns
    done
    ip netns delete balancer0_ns
    ip netns delete $BRIDGE_NS
    ;;

log)
    echo -n 1 | sudo tee /sys/kernel/debug/tracing/options/trace_printk
    sudo cat /sys/kernel/debug/tracing/trace_pipe
    ;;

ping_from)
    ITF=$2
    DEST=$3
    sudo ip netns exec ${ITF}_ns ping -4 -v -R $DEST
    ;;

attach)
    sudo ip netns exec balancer0_ns xdp-loader load -m skb -n xdp_redirect_func -vv veth0 xdp_balancer.o
    ;;

detach)
    sudo ip netns exec balancer0_ns xdp-loader unload -a veth0
    ;;

send_udp)
    ITF=$2
    DEST=$3
    sudo ip netns exec ${ITF}_ns bash -c "echo 'hello from ${ITF}' | nc -u -w0 $DEST  9999"
    ;;

listen_udp)
    ITF=$2
    sudo ip netns exec ${ITF}_ns bash -c "nc -u -l -k 9999"
    ;;

esac
