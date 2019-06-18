# Load the Rails application.
require_relative 'application'

config.frameworks -= [ :active_record, :active_resource, :action_mailer]

# Initialize the Rails application.
Rails.application.initialize!
