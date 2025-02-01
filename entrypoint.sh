#!/bin/sh
set -e

PACKAGE_DIR="/usr/share/nginx/html/packages"
PACKAGE_FILE="$PACKAGE_DIR/Packages.gz"
GITHUB_REPO_LIST="painteau/apt-server"
REPOS_FILE="$PACKAGE_DIR/repos.txt"

# Nettoyage du dossier des paquets
rm -rf "$PACKAGE_DIR"/*.deb "$PACKAGE_FILE"

# Récupérer le fichier repos.txt depuis le dépôt painteau/apt-server
echo "Fetching repos.txt from $GITHUB_REPO_LIST..."
LATEST_REPOS_URL=$(curl -s "https://api.github.com/repos/$GITHUB_REPO_LIST/contents/repos.txt" | grep "download_url" | cut -d '"' -f 4)

if [ -n "$LATEST_REPOS_URL" ]; then
    wget -q -O "$REPOS_FILE" "$LATEST_REPOS_URL"
    echo "repos.txt downloaded."
else
    echo "Failed to fetch repos.txt. Exiting."
    exit 1
fi

# Télécharger les dernières releases des dépôts listés dans repos.txt
while IFS= read -r GITHUB_REPO; do
    echo "Fetching latest release from $GITHUB_REPO..."
    LATEST_DEB_URL=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep "browser_download_url" | grep ".deb" | cut -d '"' -f 4)

    if [ -n "$LATEST_DEB_URL" ]; then
        echo "Downloading $LATEST_DEB_URL..."
        wget -q -P "$PACKAGE_DIR" "$LATEST_DEB_URL"
        echo "Download complete."
    else
        echo "No .deb file found for $GITHUB_REPO."
    fi
done < "$REPOS_FILE"

# Générer Packages.gz si des fichiers .deb sont présents
if find "$PACKAGE_DIR" -maxdepth 1 -type f -name "*.deb" | grep -q .; then
    echo "Generating Packages.gz..."
    dpkg-scanpackages "$PACKAGE_DIR" /dev/null | gzip -9c > "$PACKAGE_FILE"
    echo "Packages.gz generated."
else
    echo "No .deb files found. Skipping Packages.gz generation."
fi

# Ensure correct permissions
chown -R nginx:nginx "$PACKAGE_DIR"

# Start Nginx
exec "$@"