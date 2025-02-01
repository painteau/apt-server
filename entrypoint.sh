#!/bin/sh
set -e

PACKAGE_DIR="/usr/share/nginx/html/packages"
GITHUB_REPO_LIST="painteau/apt-server"
REPOS_FILE="$PACKAGE_DIR/repos.txt"
OVERRIDE_FILE="$PACKAGE_DIR/override"
SYNC_INTERVAL=300  # Sync every 5 minutes (300 seconds)
UBUNTU_VERSIONS="bionic focal jammy noble"
ARCHITECTURES="amd64 arm64"

# 🏗️ **Create repository structure**
create_repo_structure() {
    for DIST in $UBUNTU_VERSIONS; do
        for ARCH in $ARCHITECTURES; do
            mkdir -p "$PACKAGE_DIR/dists/$DIST/main/binary-$ARCH"
        done
    done
    mkdir -p "$PACKAGE_DIR/pool/main"
}

# 🔄 **Fetch latest packages from GitHub**
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

        LATEST_DEB_URLS=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases" | grep "browser_download_url" | grep ".deb" | cut -d '"' -f 4)

        if [ -n "$LATEST_DEB_URLS" ]; then
            for URL in $LATEST_DEB_URLS; do
                FILE_NAME=$(basename "$URL")

                if [ ! -f "$PACKAGE_DIR/pool/main/$FILE_NAME" ]; then
                    echo "Downloading $URL..."
                    wget --verbose -P "$PACKAGE_DIR/pool/main" "$URL"

                    if [ $? -eq 0 ]; then
                        echo "Download complete."
                    else
                        echo "ERROR: Failed to download $URL"
                    fi
                else
                    echo "File $FILE_NAME already exists, skipping download."
                fi
            done
        else
            echo "No .deb file found for $GITHUB_REPO."
        fi
    done < "$REPOS_FILE"

    # 🗑️ Clean up `repos.txt`
    rm -f "$REPOS_FILE"
}

# 📝 **Generate `override` file**
generate_override() {
    echo "Regenerating override file..."
    > "$OVERRIDE_FILE"  # Clear the file

    find "$PACKAGE_DIR/pool/main" -maxdepth 1 -type f -name "*.deb" | while read DEB_FILE; do
        PACKAGE_NAME=$(dpkg-deb --show --showformat='${Package}\n' "$DEB_FILE")
        SECTION="utils"
        PRIORITY="optional"

        echo "$PACKAGE_NAME $PRIORITY $SECTION" >> "$OVERRIDE_FILE"
        echo "Added override entry: $PACKAGE_NAME $PRIORITY $SECTION"
    done
}

generate_metadata() {
    echo "Generating repository metadata..."

    for DIST in $UBUNTU_VERSIONS; do
        for ARCH in $ARCHITECTURES; do
            BIN_DIR="$PACKAGE_DIR/dists/$DIST/main/binary-$ARCH"

            echo "Generating Packages.gz for $DIST $ARCH..."
            dpkg-scanpackages --multiversion "$PACKAGE_DIR/pool/main" "$OVERRIDE_FILE" | gzip -9c > "$BIN_DIR/Packages.gz"
            dpkg-scanpackages --multiversion "$PACKAGE_DIR/pool/main" "$OVERRIDE_FILE" > "$BIN_DIR/Packages"

            echo "Generating Release file for $DIST..."
            RELEASE_FILE="$PACKAGE_DIR/dists/$DIST/Release"

            cat <<EOF > "$RELEASE_FILE"
Origin: Gochu APT Server
Label: Gochu Repository
Suite: stable
Version: 1.0
Codename: $DIST
Architectures: $ARCHITECTURES
Components: main
Description: Custom APT repository for Ubuntu
Date: $(date -Ru)
EOF

            # Ajouter les checksums (MD5, SHA1, SHA256) avec chemins relatifs
            echo "Adding hash sums to Release file..."
            echo "" >> "$RELEASE_FILE"
            echo "MD5Sum:" >> "$RELEASE_FILE"
            find "$BIN_DIR" -type f -exec md5sum {} \; | sed "s|$PACKAGE_DIR|/packages|g" >> "$RELEASE_FILE"

            echo "" >> "$RELEASE_FILE"
            echo "SHA1:" >> "$RELEASE_FILE"
            find "$BIN_DIR" -type f -exec sha1sum {} \; | sed "s|$PACKAGE_DIR|/packages|g" >> "$RELEASE_FILE"

            echo "" >> "$RELEASE_FILE"
            echo "SHA256:" >> "$RELEASE_FILE"
            find "$BIN_DIR" -type f -exec sha256sum {} \; | sed "s|$PACKAGE_DIR|/packages|g" >> "$RELEASE_FILE"

            echo "Release file updated with hashes!"
        done
    done

    echo "Metadata generation complete."

    # Nettoyage après génération
    rm -f "$OVERRIDE_FILE"
    chown -R nginx:nginx "$PACKAGE_DIR"
}

# 🏁 **Start repository setup**
create_repo_structure
fetch_packages
generate_override
generate_metadata

# 🔄 **Start background sync**
while true; do
    echo "Waiting $SYNC_INTERVAL seconds before next sync..."
    sleep "$SYNC_INTERVAL"
    fetch_packages
    generate_override
    generate_metadata
done &

# 🚀 **Start Nginx**
exec "$@"