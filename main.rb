require_relative './config'
require 'clap'
require 'fallen'
require "fallen/cli"
require 'logger'
require 'fileutils'

# Ensure logs directory exists
FileUtils.mkdir_p('logs')

# Setup logger
$logger = Logger.new('logs/bot.log', 'daily')
$logger.level = Logger::INFO
$logger.formatter = proc { |severity, datetime, progname, msg| "#{datetime} [#{severity}] #{msg}\n" }

module Bot
  extend Fallen
  extend Fallen::CLI
  
  def self.run
    run_bot!
  end

  def self.run_bot!(token = TOKEN)
    $logger.info("Bot started")
    Telegram::Bot::Client.run(token.strip) do |bot|
      t = Thread.new { run_sender! }
      bot.listen do |m|
        begin
          result = ProcessMessage.new(m, bot).process
          Sender.new(bot, result)
        rescue => e
          $logger.error("Error handling incoming message: #{e.class} - #{e.message}") if defined?($logger)
          $logger.error(e.backtrace.join("\n")) if defined?($logger)
        end
      end
    rescue => e
      $logger.error("Bot error: #{e.class} - #{e.message}")
      $logger.error(e.backtrace.join("\n"))
      t.kill
      sleep 5
      redo
    end
  end

  def self.run_sender!(token = TOKEN)
    $logger.info("Sender thread started")
    bot = Telegram::Bot::Client.new(token.strip)

    while
      current_time = Time.now.to_s.split[1].split(":")[..1]
      schedule_time = SETTINGS[:time_to_send].map { |t| t.split(':') }

      if schedule_time.include?(current_time)
        $logger.info("Sending scheduled messages at #{Time.now}")
        begin
          AdminMessages.send_all_requests(bot)
          $logger.info("Scheduled messages sent successfully")
        rescue => e
          $logger.error("Error sending scheduled messages: #{e.class} - #{e.message}")
          $logger.error(e.backtrace.join("\n"))
        end
      end

      sleep 58
    end
  rescue => e
    $logger.error("Sender thread error: #{e.class} - #{e.message}")
    $logger.error(e.backtrace.join("\n"))
    sleep 5
    retry
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
  puts "Usage: ruby main.rb [start|stop]"
end


  