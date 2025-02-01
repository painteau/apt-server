#!/bin/sh
set -e

PACKAGE_DIR="/usr/share/nginx/html/packages"
PACKAGE_FILE="$PACKAGE_DIR/Packages.gz"
GITHUB_REPO_LIST="painteau/apt-server"
REPOS_FILE="$PACKAGE_DIR/repos.txt"

# Clean up old package files
rm -rf "$PACKAGE_DIR"/*.deb "$PACKAGE_FILE"

# Ensure the package directory exists and has proper permissions
mkdir -p "$PACKAGE_DIR"
chown -R nginx:nginx "$PACKAGE_DIR"
chmod -R 775 "$PACKAGE_DIR"

# Fetch repos.txt from the GitHub repository
echo "Fetching repos.txt from $GITHUB_REPO_LIST..."
LATEST_REPOS_URL=$(curl -s "https://api.github.com/repos/$GITHUB_REPO_LIST/contents/repos.txt" | grep "download_url" | cut -d '"' -f 4)

if [ -n "$LATEST_REPOS_URL" ]; then
    wget -O "$REPOS_FILE" "$LATEST_REPOS_URL"
    echo "repos.txt downloaded."
else
    echo "Failed to fetch repos.txt. Exiting."
    exit 1
fi

# Display the content of repos.txt for debugging
echo "---- repos.txt content ----"
cat "$REPOS_FILE"
echo "----------------------------"

# Download the latest .deb files for each repository listed in repos.txt
while IFS= read -r GITHUB_REPO || [ -n "$GITHUB_REPO" ]; do
    echo "Processing repo: '$GITHUB_REPO'..."

    # Fetch the latest .deb file URL
    LATEST_DEB_URL=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep "browser_download_url" | grep ".deb" | cut -d '"' -f 4)

    echo "Found URL: '$LATEST_DEB_URL'"

    if [ -n "$LATEST_DEB_URL" ]; then
        echo "Downloading $LATEST_DEB_URL..."
        
        # Sleep to avoid API rate limits
        sleep 2
        
        wget --verbose -P "$PACKAGE_DIR" "$LATEST_DEB_URL"

        if [ $? -eq 0 ]; then
            echo "Download complete."
        else
            echo "ERROR: Failed to download $LATEST_DEB_URL"
        fi
    else
        echo "No .deb file found for $GITHUB_REPO."
    fi
done < "$REPOS_FILE"

# Generate Packages.gz if .deb files exist
if find "$PACKAGE_DIR" -maxdepth 1 -type f -name "*.deb" | grep -q .; then
    echo "Generating Packages.gz..."
    
    # Create an empty override file to avoid warnings
    touch /usr/share/nginx/html/packages/override

    # Generate Packages.gz using the override file
    dpkg-scanpackages "$PACKAGE_DIR" /usr/share/nginx/html/packages/override | gzip -9c > "$PACKAGE_FILE"

    echo "Packages.gz generated."
else
    echo "No .deb files found. Skipping Packages.gz generation."
fi

# Ensure correct permissions
chown -R nginx:nginx "$PACKAGE_DIR"

# Start Nginx
exec "$@"