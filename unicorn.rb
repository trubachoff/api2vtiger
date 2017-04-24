# Set the working application directory
working_directory "/srv/parser2vtiger"

# Unicorn PID file location
pid "/var/run/parser2vtiger/unicorn.pid"

# Path to logs
stderr_path "/var/log/parser2vtiger/unicorn.log"
stdout_path "/var/log/parser2vtiger/unicorn.log"

# Unicorn socket
listen "/var/run/parser2vtiger/unicorn.sock"

# Number of processes
worker_processes 4

# Time-out
timeout 30
