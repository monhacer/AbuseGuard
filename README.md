<div align="center">

# 🛡️ AbuseGuard

**High-Performance Kernel-Level Outbound Traffic Sanitizer & Abuse Blocker**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%28Ubuntu%20%2F%20Debian%29-orange.svg?style=flat-square)](#requirements)
[![Firewall](https://img.shields.io/badge/Engine-iptables-green.svg?style=flat-square)](#features)
[![Repo](https://img.shields.io/badge/GitHub-monhacer%2FAbuseGuard-lightgrey.svg?style=flat-square&logo=github)](https://github.com/monhacer/AbuseGuard)

<p align="center">
  Stop hosting account suspensions on Hetzner, OVH, DigitalOcean, and other VPS providers by pre-emptively mitigating outbound port scanning, private CIDR leakages, and known abusive endpoints.
</p>

</div>

---

## ⚡ Quick Start (One-Line Execution)

Run AbuseGuard directly on your server with a single command:

```bash
bash <(curl -s https://raw.githubusercontent.com/monhacer/AbuseGuard/refs/heads/main/abuseguard.sh)
