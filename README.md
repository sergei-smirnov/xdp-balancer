# Primitive XDP balancer


Clone the repository recursively

## Dependencies

### xdp-tools

```bash
cd 3rdparty/xdp-tools
make
sudo make install
```

## Testing Environment

### Setup

```bash
sudo ./testenv.sh up

```

### Cleanup

```bash
sudo ./testenv.sh down

```

### Attach

```bash
sudo ./testenv.sh attach
```

### Detach

```bash
sudo ./testenv.sh detach
```

### Log


```bash
sudo ./testenv.sh log
```

### Ping From


```bash
sudo ./testenv.sh ping_from <iface> <ip>
```