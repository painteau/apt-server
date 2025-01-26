# apt-server

**Status**: Work in Progress 🚧

A lightweight APT server built using Docker and Nginx (based on Alpine), capable of hosting Debian/Ubuntu packages. This repository automates the process of creating and deploying an APT server image with multi-platform support and GitHub Actions integration. The server also automatically generates the `Packages.gz` index file when the container starts.

---

## Features

- **Lightweight**: Uses Nginx on Alpine for minimal resource usage.
- **Multi-Architecture Support**: Builds for `amd64`, `arm64`, and `arm/v7`.
- **Automated CI/CD**: Docker images are built, pushed, and signed via GitHub Actions.
- **APT-Compatible**: Serves `.deb` packages and `Packages.gz` indexes for APT clients.
- **Automatic Package Indexing**: Automatically generates `Packages.gz` when the Docker container starts.

---

## Usage

### Clone the Repository

```bash
git clone https://github.com/painteau/apt-server.git
cd apt-server
```

### Build and Run Locally

1. **Build the Docker image:**
   ```bash
   docker build -t apt-server .
   ```

2. **Run the container:**
   ```bash
   docker run --name apt-server -p 8080:80 -v /path/to/your/packages:/usr/share/nginx/html/packages -d apt-server
   ```

### Use the APT Server on Clients

1. **Add the APT server to your client machine:**
   ```bash
   echo "deb [trusted=yes] http://<host-ip>:8080/packages ./" | sudo tee -a /etc/apt/sources.list
   sudo apt update
   ```

2. **Install your package:**
   ```bash
   sudo apt install <your-package>
   ```

---

## Preparing Your Packages

When the Docker container starts, it automatically generates the `Packages.gz` index file for any `.deb` files located in `/path/to/your/packages`. Simply add or update `.deb` files in the mounted directory and restart the container if needed.

1. **Place `.deb` files in your local directory:**
   ```bash
   mkdir -p /path/to/your/packages
   mv your-package.deb /path/to/your/packages
   ```

2. **Restart the container (if needed):**
   ```bash
   docker restart apt-server
   ```

---

## GitHub Actions Workflow

### Overview

This repository includes a GitHub Actions workflow to automate the build, push, and signing of Docker images.

### Key Features

- **Triggers:**
  - Scheduled builds every Monday at 08:08 (UTC).
  - Builds on push to the `main` branch.
  - Builds on version tags (e.g., `v1.0.0`).
  - Builds on pull requests targeting `main`.

- **Multi-Platform Builds:** Images are built for `amd64`, `arm64`, and `arm/v7`.

- **Image Signing:** Docker images are signed using `cosign` for enhanced security.

### How It Works

1. **Build and Push:** The workflow builds a Docker image and pushes it to the GitHub Container Registry (`ghcr.io`).
2. **Sign Images:** The workflow signs the published image using `cosign`.

### Running the Workflow

The workflow runs automatically on the specified triggers. To manually trigger it, you can use the "Run workflow" button in the Actions tab of your GitHub repository.

---

## Docker Image

The Docker image is published to:

```
ghcr.io/painteau/apt-server
```

You can pull the latest image with:

```bash
docker pull ghcr.io/painteau/apt-server:latest
```

---

## Roadmap

- [ ] Add support for HTTPS with Let's Encrypt.
- [ ] Improve documentation for advanced use cases.
- [ ] Add integration tests for package serving.

---

## Contributions

Contributions are welcome! Feel free to open issues or submit pull requests to improve the project.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

