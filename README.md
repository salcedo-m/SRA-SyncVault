# SRA-SyncVault v2.0 

**Automated, fault-tolerant pipeline for NCBI SRA sequence extraction, on-the-fly compression, and secure hardware exfiltration.**

Designed for genomic data engineering, this tool ensures data integrity during massive sequence downloads, prevents storage collapse through real-time GZIP compression, and mitigates hardware thermal throttling during extended operations.

## Core Features

* **Interactive CLI:** Guided user interface for dynamic file and directory targeting without editing the source code.
* **Network Fault Tolerance:** Autonomous retry loops (`while`) to survive ISP micro-disconnections during heavy `prefetch` operations.
* **On-the-Fly Compression:** Simultaneous extraction and `.gz` compression to bypass local storage bottlenecks.
* **Hardware Thermal Shielding:** Scheduled CPU cooling cycles (`sleep`) to prevent thermal throttling.
* **Pre-Flight Auditing:** Automated validation of SRA Toolkit dependencies and minimum storage requirements (60GB+).

## Prerequisites

1. **UNIX Environment:** Linux or macOS (WSL required for Windows).
2. **SRA Toolkit:** `prefetch` and `fastq-dump` must be installed and added to your system PATH.
3. **Storage:** Minimum of 60 GB of free local storage.

## Quick Start

1. Clone the repository and grant execution permissions:
   ```bash
   git clone [https://github.com/salcedo-m/SRA-SyncVault.git](https://github.com/salcedo-m/SRA-SyncVault.git)
   cd SRA-SyncVault
   chmod +x sra_syncvault.sh
   ```
2. Execute the engine:
   ```bash
   ./sra_syncvault.sh
   ```
3. Follow the on-screen prompts to specify your sequence ID list and target export directory.
