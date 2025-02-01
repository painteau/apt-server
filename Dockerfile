FROM nginx:alpine

# Install required tools
RUN apk add --no-cache dpkg-dev curl wget

# Create directory for packages
RUN mkdir -p /usr/share/nginx/html/packages

# Copy custom entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose HTTP port
EXPOSE 80

# Set custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]