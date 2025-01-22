# ERPNext Installation Script with Optimizations

This script automates the installation of **ERPNext**, a powerful open-source ERP system, while applying **best practices** and **performance optimizations** tailored to your server's resources. It is designed to simplify the setup process, ensuring a smooth and efficient deployment of ERPNext on **Ubuntu** or **Debian** systems.

---

## Key Features

1. **Automated ERPNext Installation**:
   - Installs ERPNext versions **13**, **14**, or **15** based on user selection.
   - Handles dependencies, including Python, Node.js, MariaDB, Redis, and more.

2. **Resource-Based Optimizations**:
   - Dynamically adjusts **MariaDB** settings (e.g., buffer pool size, max connections) based on available RAM and CPU cores.
   - Optimizes **Node.js** memory limits for better performance.
   - Configures **Python** garbage collection and installs performance monitoring tools.

3. **System-Wide Performance Tuning**:
   - Increases file descriptor limits for better scalability.
   - Adjusts kernel parameters for improved TCP performance and reduced swap usage.
   - Optimizes disk I/O settings, especially for SSDs.

4. **ERPNext Bench Optimization**:
   - Configures worker counts for background jobs and Gunicorn based on CPU cores.
   - Enables **Redis** for caching, queues, and Socket.IO for better performance.

5. **SSL Certificate Installation**:
   - Optionally installs **Let's Encrypt SSL certificates** for secure access to your ERPNext site.

6. **User-Friendly Prompts**:
   - Guides the user through version selection, database password setup, and other configurations.
   - Provides clear feedback and progress updates during installation.

7. **Error Handling**:
   - Includes robust error handling to ensure the script exits gracefully in case of failures.
   - Logs errors with line numbers for easier debugging.

8. **Compatibility Checks**:
   - Validates the operating system and version to ensure compatibility with ERPNext.
   - Checks for minimum Python and Node.js versions and installs them if necessary.

9. **Production-Ready Setup**:
   - Configures **Supervisor** and **Nginx** for production environments.
   - Enables and resumes the scheduler for automated background tasks.

10. **Development Mode Support**:
    - Sets up ERPNext for development with `bench start` for local testing.

---

## What the Script Does

1. **Installs Dependencies**:
   - Git, Curl, Python 3.10+, Node.js, MariaDB, Redis, and other required packages.

2. **Configures MariaDB**:
   - Secures the database with a user-provided root password.
   - Optimizes InnoDB settings, connection limits, and query performance.

3. **Sets Up ERPNext**:
   - Initializes the Bench environment.
   - Creates a new site with the provided name and administrator password.
   - Installs ERPNext and optional apps like **HRMS**.

4. **Optimizes Performance**:
   - Adjusts system, database, and application settings for optimal performance.

5. **Configures Production Environment**:
   - Sets up Supervisor and Nginx for production deployment.
   - Optionally installs SSL certificates for secure access.

6. **Provides Clear Instructions**:
   - Guides the user through the installation process with prompts and feedback.
   - Displays success messages and next steps after installation.

---

## How to Use

1. **Download the Script**:
   ```bash
   wget https://example.com/erpnext_installer.sh
   ```

2. **Make It Executable**:
   ```bash
   chmod +x erpnext_installer.sh
   ```

3. **Run the Script**:
   ```bash
   sudo ./erpnext_installer.sh
   ```

4. **Follow the Prompts**:
   - Select the ERPNext version.
   - Provide a database root password.
   - Enter the site name and administrator password.
   - Choose whether to install SSL and additional apps like HRMS.

5. **Access ERPNext**:
   - After installation, access ERPNext at `http://<your-server-ip>` or `https://<your-domain>` (if SSL is enabled).

---

## System Requirements

- **Operating System**: Ubuntu 20.04/22.04 or Debian 10/11/12.
- **RAM**: Minimum 4GB (8GB or more recommended for production).
- **CPU**: 2 cores or more.
- **Disk Space**: At least 20GB of free space.

---

## Why Use This Script?

- **Saves Time**: Automates the entire ERPNext installation process.
- **Ensures Best Practices**: Applies performance optimizations and security settings.
- **Customizable**: Allows users to choose ERPNext versions and optional features.
- **Production-Ready**: Configures the system for high-performance, scalable deployments.

---

## Example Output

```
Welcome to the ERPNext Installer...

Please enter the number of the corresponding ERPNext version you wish to install:
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

Congratulations! You have successfully installed ERPNext Version 14.
You can start using your new ERPNext installation by visiting https://your-site.com.
Enjoy using ERPNext!
