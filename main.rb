require_relative './config'
require 'clap'
require 'fallen'
require "fallen/cli"

module Bot
  extend Fallen
  extend Fallen::CLI
  
  def self.run
    Thread.new { run_sender! }
    run_bot!
  end

  def self.run_bot!(token = TOKEN)
    Telegram::Bot::Client.run(token) do |bot|
      bot.listen { |m| Sender.new(bot, ProcessMessage.new(m).process) }
    rescue => e
      puts e
      puts e.backtrace
      redo
    end
  end

  def run_sender!
  end
end

case Clap.run(ARGV, Bot.cli).first
when "start"
  Bot.pid_file "./bot.pid"
  Bot.daemonize!
  Bot.start!
when "stop"
  Bot.stop!
else
  Bot.usage
end


  