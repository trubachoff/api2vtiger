# Set the working application directory
working_directory '/srv/api4vtiger'

# Unicorn PID file location
pid '/var/run/api4vtiger/unicorn.pid'

# Path to logs
stderr_path '/var/log/api4vtiger/unicorn.log'
stdout_path '/var/log/api4vtiger/unicorn.log'

# Unicorn socket
listen '/var/run/api4vtiger/unicorn.sock'

# Number of processes
worker_processes 4

# Time-out
timeout 30
