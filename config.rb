require 'active_record'
require 'sqlite3'
require 'telegram/bot'
require 'yaml'
require 'aasm'
require 'byebug'

require_relative './models/user'
require_relative './models/application'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: './db/data.db')
ActiveRecord::MigrationContext.new('./db/migrations', ActiveRecord::SchemaMigration).migrate
