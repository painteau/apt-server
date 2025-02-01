# 📦 APT Server - Host Your Own Debian Package Repository

`apt-server` is a **self-hosted APT repository** that allows you to **distribute `.deb` packages** for Debian-based systems.

✅ **Automatically fetches `.deb` files** from GitHub releases.  
✅ **Supports multiple versions** of each package.  
✅ **Automatically regenerates `Packages.gz`** to keep the repo updated.  
✅ **Served via Nginx** for easy access.  

—

## 🚀 Getting Started

### 1️⃣ Fork This Repository
To customize your package sources, **fork this repository** on GitHub.  
This allows you to modify `repos.txt` to define which packages should be included.

### 2️⃣ Clone Your Fork
```sh
git clone https://github.com/YOUR_GITHUB_USERNAME/apt-server.git
cd apt-server
```

### 3️⃣ Build the Docker Image
```sh
docker build -t YOUR_USERNAME/apt-server .
```

### 4️⃣ Run the APT Server
```sh
docker run —name apt-server -p 3094:80 -d —label com.centurylinklabs.watchtower.enable=true YOUR_USERNAME/apt-server
```
✅ The APT repository will be available at:  
```
http://localhost:3094/packages/
```

—

## 📥 Adding `.deb` Packages

### 🔹 Step 1: Modify `repos.txt` in Your Fork
The server pulls `.deb` files from **GitHub releases**.  
In your fork, edit `repos.txt` to list repositories (one per line):

```
username/repo1
username/repo2
```
📌 **These repositories must have `.deb` files in their latest releases.**

### 🔹 Step 2: Push Changes to Your Fork
After modifying `repos.txt`, push the changes to GitHub:
```sh
git add repos.txt
git commit -m “Updated package sources”
git push origin main
```

### 🔹 Step 3: Restart the Server to Sync
```sh
docker restart apt-server
```
✅ New `.deb` packages will be downloaded **automatically** every 5 minutes.

—

## 🖥️ Using the APT Repository

### 1️⃣ Add the APT Source
On a Debian/Ubuntu system, add the repository:
```sh
echo “deb [trusted=yes] http://localhost:3094/ ./“ | sudo tee /etc/apt/sources.list.d/custom.list
```

### 2️⃣ Update APT
```sh
sudo apt update
```

### 3️⃣ Install a Package
```sh
sudo apt install package-name
```
📌 **By default, APT installs the latest version** of the package.

—

## 🏷 Installing Specific Versions

### 1️⃣ List Available Versions
```sh
apt-cache madison package-name
```
✅ **Example output:**
```
package-name | 1.2.3 | http://localhost:3094 ./ Packages
package-name | 1.2.2 | http://localhost:3094 ./ Packages
package-name | 1.2.1 | http://localhost:3094 ./ Packages
```

### 2️⃣ Install a Specific Version
```sh
sudo apt install package-name=1.2.2
```

—

## 🔄 How the Server Works

1️⃣ **Every 5 minutes**, the server:
   - Fetches the latest `repos.txt` from your GitHub fork.
   - Downloads **all available `.deb` versions** from each repository.
   - Regenerates `Packages.gz` for APT.
   - Removes unnecessary files.

2️⃣ **APT Clients can install packages** directly using `apt install package-name`.

—

## 🛠️ Advanced Configuration

### 🔹 Change the Sync Interval
By default, the server **syncs every 5 minutes** (`300s`).  
To change it, modify **`entrypoint.sh`** in your fork:
```sh
SYNC_INTERVAL=600  # Sync every 10 minutes
```

### 🔹 Run the Server on a Different Port
By default, the server runs on port **3094**. To change it:
```sh
docker run —name apt-server -p 8080:80 -d YOUR_USERNAME/apt-server
```
Now, the APT repository will be available at:
```
http://localhost:8080/packages/
```

—

## 🛠 Troubleshooting

### 🔹 Check Logs for Errors
If the server is not working correctly, check the logs:
```sh
docker logs -f apt-server
```

### 🔹 Verify `.deb` Files Are Downloaded
```sh
docker exec apt-server ls -l /usr/share/nginx/html/packages
```
✅ You should see multiple `.deb` files listed.

### 🔹 Force a Manual Sync
If new packages are not appearing, trigger a manual sync:
```sh
docker exec apt-server sh -c “fetch_packages”
```

—

## 🚀 Contributing
1️⃣ **Fork the repository**  
2️⃣ **Modify `repos.txt` and push changes**  
3️⃣ **Submit a pull request if you have general improvements**  

—

## 📝 License
This project is licensed under the **MIT License**.  
Feel free to use, modify, and distribute it!