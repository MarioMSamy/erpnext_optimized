# ERPNext Advanced Installer

This repository contains a **comprehensive installation script** for deploying ERPNext with advanced optimizations. It simplifies the deployment process and ensures optimal performance on **Ubuntu** or **Debian** systems.

---

## Features

1. **Automated ERPNext Installation**
   - Supports ERPNext versions **13**, **14**, and **15**.
   - Handles dependencies: Python, Node.js, MariaDB, Redis, Nginx, and more.

2. **Dynamic Resource Optimization**
   - Configures MariaDB settings based on available RAM and CPU.
   - Optimizes Node.js memory allocation and Python garbage collection.

3. **Enhanced Performance Tuning**
   - Increases file descriptor limits for scalability.
   - Adjusts kernel parameters for faster TCP and reduced swap usage.
   - SSD-specific optimizations for improved disk I/O.

4. **Production-Ready Setup**
   - Configures Supervisor and Nginx.
   - Optional SSL installation using Let's Encrypt.
   - Enables background job workers and caching via Redis.

5. **Rollback and Error Handling**
   - Includes robust error handling with rollback support for failed installations.
   - Logs all actions for troubleshooting.

6. **Customizable and User-Friendly**
   - Allows interactive prompts for configuration.
   - Validates domain names and passwords for reliability.

---

## How to Use

### Download the Script
```bash
wget https://raw.githubusercontent.com/MarioMSamy/erpnext_optimized/refs/heads/main/erpnext_installer.sh
```

### Make It Executable
```bash
chmod +x advanced_erpnext_installer.sh
```

### Run the Script
```bash
sudo ./advanced_erpnext_installer.sh
```

### Follow the Prompts
- Provide the ERPNext version, database credentials, and domain name.
- Select optional configurations like SSL and additional apps.

### Access ERPNext
- After installation, visit:
  - `http://<your-server-ip>`
  - `https://<your-domain>` (if SSL is enabled)

---

## System Requirements

- **Operating System**: Ubuntu 20.04/22.04 or Debian 10/11/12.
- **RAM**: Minimum 4GB (8GB recommended).
- **CPU**: 2 cores or more.
- **Disk Space**: At least 20GB free.

---

## Change Log

### Version 2.0
- Added rollback functionality for safer installations.
- Enhanced error handling with detailed logging.
- Introduced SSD-specific optimizations.
- Improved domain validation for SSL setup.
- Added support for Python 3.10 and custom Node.js versions.

### Version 1.1
- Integrated advanced MariaDB tuning based on server resources.
- Optimized TCP and memory configurations for better scalability.
- Included a retry mechanism for failed commands.

### Version 1.0
- Initial release with automated ERPNext installation.
- Basic dependency management and performance tuning.

---

## Why Use This Script?

- **Comprehensive**: Automates installation with advanced optimizations.
- **Reliable**: Handles errors and provides rollback support.
- **Scalable**: Configures server settings for high performance.
- **Secure**: Supports SSL installation for secure access.

---

## Example Output

```bash
Welcome to the ERPNext Installer...

Please enter the ERPNext version:
1) Version 13
2) Version 14
3) Version 15
#? 2

You have selected Version 14 for installation.
Do you wish to continue? (yes/no): yes

Installing dependencies...
Optimizing MariaDB configuration...
Setting up ERPNext site...
Production setup complete!

Congratulations! ERPNext Version 14 is now ready.
Access your installation at https://your-site.com or http://<server-ip>.
Enjoy using ERPNext!
