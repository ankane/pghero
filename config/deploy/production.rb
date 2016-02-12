# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

server '52.11.92.125', user: 'ubuntu', roles: %w{app db web}, primary: true
#server '172.31.19.13', user: 'ubuntu', roles: %w{app db web}, primary: true

# server 'example.com', user: 'deploy', roles: %w{app web}, other_property: :other_value
# server 'db.example.com', user: 'deploy', roles: %w{db}



# role-based syntax
# ==================

# Defines a role with one or multiple servers. The primary server in each
# group is considered to be the first unless any  hosts have the primary
# property set. Specify the username and a domain or IP for the server.
# Don't use `:all`, it's a meta role.

role :app, %w{52.11.92.125}, port: '2222'
role :web, %w{52.11.92.125}, port: '2222'
role :db,  %w{52.11.92.125},  port: '2222'



# Configuration
# =============
# You can set any configuration variable like in config/deploy.rb
# These variables are then only loaded and set in this stage.
# For available Capistrano configuration variables see the documentation page.
# http://capistranorb.com/documentation/getting-started/configuration/
# Feel free to add new variables to customise your setup.



# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult the Net::SSH documentation.
# http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start
#
# Global options
# --------------
 set :ssh_options, {
   port: 22,
   #keys: "~/vagrant.d/insecure_private_key",
   forward_agent: true,
   #keys: %w(/Volumes/Macintosh2/Users/brucebotes/.ssh/id_rsa)
   keys: %w(/home/bruce/.ssh/EC2_twighorse.pem)
   #forward_agent: false
   #auth_methods: %w(password)
 }
#
# The server-based syntax can be used to override options:
# ------------------------------------
# server 'example.com',
#   user: 'user_name',
#   roles: %w{web app},
#   ssh_options: {
#     user: 'user_name', # overrides user setting above
#     keys: %w(/home/user_name/.ssh/id_rsa),
#     forward_agent: false,
#     auth_methods: %w(publickey password)
#     # password: 'please use keys'
#   }
