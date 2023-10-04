#include <bpf_endian.h>
#include <bpf_helpers.h>
#include <linux/bpf.h>
#include <linux/in.h>
#include <parsing_helpers.h>

// user-space util to fill this map
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __type(key, unsigned int);
    __type(value, unsigned int);
    __uint(max_entries, 16);
} redirect_params SEC(".maps");

static __always_inline __u16 csum_fold_helper(__u32 csum)
{
    __u32 sum;
    sum = (csum >> 16) + (csum & 0xffff);
    sum += (sum >> 16);
    return ~sum;
}

/* eBPF lacks these functions, but LLVM provides builtins */
#ifndef memset
#define memset(dest, chr, n) __builtin_memset((dest), (chr), (n))
#endif

#ifndef memcpy
#define memcpy(dest, src, n) __builtin_memcpy((dest), (src), (n))
#endif

#ifndef memmove
#define memmove(dest, src, n) __builtin_memmove((dest), (src), (n))
#endif

SEC("xdp")
int xdp_tx_func(struct xdp_md* ctx)
{
    bpf_printk("xdp_tx_func\n");
    return XDP_TX;
}

SEC("xdp")
int xdp_redirect_func(struct xdp_md* ctx)
{
    void* data_end = (void*)(long)ctx->data_end;
    void* data = (void*)(long)ctx->data;
    struct hdr_cursor nh;
    struct ethhdr* eth;
    int eth_type, ip_proto;
    int action = XDP_PASS;
    struct iphdr* iph;
    struct iphdr iph_old;
    unsigned short csum, old_cksum;

    unsigned int src_ip = 0xC0000080;
    unsigned int dst_ip = 0xC0000202;

    unsigned char dst_mac[ETH_ALEN] = {
        0x76, 0x63, 0x51, 0x9d, 0xc4, 0x69
    };

    bpf_printk("xdp_redirect_func");

    /* These keep track of the next header type and iterator pointer */
    nh.pos = data;

    /* Parse Ethernet and IP/IPv6 headers */
    eth_type = parse_ethhdr(&nh, data_end, &eth);
    if (eth_type == -1)
        goto out;

    bpf_printk("Proto: %X", eth->h_proto);

    if (eth->h_proto == bpf_htons(ETH_P_IP)) {
        bpf_printk("IPv4");

        ip_proto = parse_iphdr(&nh, data_end, &iph);
        if (ip_proto == -1)
            goto out;

        bpf_printk("IP src: %x", bpf_ntohl(iph->addrs.saddr));
        bpf_printk("IP dst: %x", bpf_ntohl(iph->addrs.daddr));

        if (bpf_ntohl(iph->addrs.saddr) == src_ip) {
            // do redirect
            iph->addrs.daddr = bpf_htonl(dst_ip);
            memcpy(&eth->h_dest, dst_mac, ETH_ALEN);

            old_cksum = iph->check;
            iph->check = 0;
            iph_old = *iph;

            csum = bpf_csum_diff((__be32*)&iph_old, sizeof(struct iphdr),
                (__be32*)iph, sizeof(struct iphdr), old_cksum);
            iph->check = csum_fold_helper(csum);

            action = XDP_TX;
        }
    }
out:
    return action;
}

SEC("xdp")
int xdp_pass_func(struct xdp_md* ctx)
{
    bpf_printk("xdp_pass_func\n");
    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
