require 'active_record'
require 'sqlite3'
require 'telegram/bot'
require 'yaml'
require 'aasm'
require 'byebug'

require_relative './models/user'
require_relative './models/application'
require_relative './models/question'
require_relative './models/photo'

require_relative './lib/texts_module'
require_relative './lib/message_processor'
require_relative './lib/message_sender'
require_relative './lib/admin_messages'

unless File.exist?('token')
	raise "Missing token file. Create a file named 'token' with the bot token"
end
TOKEN = File.read('token').strip

unless File.exist?('settings.yaml')
	raise "Missing settings.yaml"
end
SETTINGS = YAML.load(File.read('settings.yaml')).with_indifferent_access

unless File.exist?('texts.yaml')
	raise "Missing texts.yaml"
end
TEXTS = YAML.load(File.read('texts.yaml')).with_indifferent_access

$previous_message = {}

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: './db/data.db')
ActiveRecord::MigrationContext.new('./db/migrations').migrate
