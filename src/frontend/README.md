## Frontend instance

### Functional intent

The frontend is the public entry point of the system.

- serves the user interface through nginx
- exposes the public browser entry point
- forwards API calls to the backend

### Structure

```text
src/frontend/
  index2.html
  nginx.conf
  README.md
```

### Deployment setup

Deploy the frontend page from `src/frontend/index2.html` and use the nginx configuration in `src/frontend/nginx.conf`.

Because the frontend is static and nginx-based, it does not use a service-specific Python requirements file.

Public entry point:

```text
http://44.212.221.75/
```

### systemd setup

nginx itself is managed as a system service:

```bash
sudo dnf install -y nginx || sudo apt install -y nginx
sudo cp /home/ec2-user/infra-automation/src/frontend/nginx.conf /etc/nginx/conf.d/infra-frontend.conf
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo systemctl status nginx
```

### Key configuration

```text
server_name 44.212.221.75
backend upstream 10.0.149.9:8000
frontend document root /home/ec2-user/infra-automation/src/frontend
```

### Current AWS attachment notes

- instance security group: `http`
- inbound public traffic: `80/tcp` from the internet
- nginx proxies requests to the backend at `10.0.149.9:8000`