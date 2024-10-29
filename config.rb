require 'active_record'
require 'sqlite3'
require 'telegram/bot'
require 'yaml'
require 'aasm'
require 'byebug'

require_relative './models/user'
require_relative './models/application'
require_relative './lib/message_processor'
require_relative './lib/message_sender'

TOKEN = File.read('token')
TEXTS = YAML.load(File.read('texts.yaml')).with_indifferent_access

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: './db/data.db')
ActiveRecord::MigrationContext.new('./db/migrations', ActiveRecord::SchemaMigration).migrate
