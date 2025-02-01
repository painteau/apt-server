#!/bin/sh
set -e

PACKAGE_DIR="/usr/share/nginx/html/packages"
PACKAGE_FILE="$PACKAGE_DIR/Packages.gz"
GITHUB_REPO_LIST="painteau/apt-server"
REPOS_FILE="$PACKAGE_DIR/repos.txt"
SYNC_INTERVAL=300  # Sync every 5 minutes (300 seconds)

fetch_packages() {
    echo "Fetching repos.txt from $GITHUB_REPO_LIST..."
    LATEST_REPOS_URL=$(curl -s "https://api.github.com/repos/$GITHUB_REPO_LIST/contents/repos.txt" | grep "download_url" | cut -d '"' -f 4)

    if [ -n "$LATEST_REPOS_URL" ]; then
        wget -q -O "$REPOS_FILE" "$LATEST_REPOS_URL"
        echo "repos.txt downloaded."
    else
        echo "Failed to fetch repos.txt. Exiting."
        exit 1
    fi

    echo "---- repos.txt content ----"
    cat "$REPOS_FILE"
    echo "----------------------------"

    while IFS= read -r GITHUB_REPO || [ -n "$GITHUB_REPO" ]; do
        echo "Processing repo: '$GITHUB_REPO'..."

        # Fetch the latest .deb file URL
        LATEST_DEB_URL=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep "browser_download_url" | grep ".deb" | cut -d '"' -f 4)

        echo "Found URL: '$LATEST_DEB_URL'"

        if [ -n "$LATEST_DEB_URL" ]; then
            FILE_NAME=$(basename "$LATEST_DEB_URL")

            # Check if file already exists
            if [ ! -f "$PACKAGE_DIR/$FILE_NAME" ]; then
                echo "Downloading $LATEST_DEB_URL..."
                wget --verbose -P "$PACKAGE_DIR" "$LATEST_DEB_URL"

                if [ $? -eq 0 ]; then
                    echo "Download complete."
                else
                    echo "ERROR: Failed to download $LATEST_DEB_URL"
                fi
            else
                echo "File $FILE_NAME already exists, skipping download."
            fi
        else
            echo "No .deb file found for $GITHUB_REPO."
        fi
    done < "$REPOS_FILE"

    # Ensure the override file exists before regenerating Packages.gz
    if [ ! -f "$PACKAGE_DIR/override" ]; then
        echo "Creating missing override file..."
        touch "$PACKAGE_DIR/override"
    fi

    # Regenerate Packages.gz if there are .deb files
    if find "$PACKAGE_DIR" -maxdepth 1 -type f -name "*.deb" | grep -q .; then
        echo "Generating Packages.gz..."
        dpkg-scanpackages "$PACKAGE_DIR" "$PACKAGE_DIR/override" | gzip -9c > "$PACKAGE_FILE"
        echo "Packages.gz generated."

        # Remove unnecessary files
        echo "Cleaning up unnecessary files..."
        rm -f "$PACKAGE_DIR/override" "$PACKAGE_DIR/repos.txt"
        echo "Cleanup complete."
    else
        echo "No .deb files found. Skipping Packages.gz generation."
    fi

    # Ensure correct permissions
    chown -R nginx:nginx "$PACKAGE_DIR"
}

# Initial package fetch
fetch_packages

# Start a background loop for periodic sync
while true; do
    echo "Waiting $SYNC_INTERVAL seconds before next sync..."
    sleep "$SYNC_INTERVAL"
    fetch_packages
done &

# Start Nginx
exec "$@"