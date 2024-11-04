require_relative './config'
require 'clap'
require 'fallen'
require "fallen/cli"

module Bot
  extend Fallen
  extend Fallen::CLI
  
  def self.run
    run_bot!
  end

  def self.run_bot!(token = TOKEN)
    Telegram::Bot::Client.run(token.strip) do |bot|
      Thread.new { run_sender! }
      bot.listen { |m| Sender.new(bot, ProcessMessage.new(m, bot).process) }
    rescue => e
      puts e
      puts e.backtrace
      redo
    end
  end

  def self.run_sender!(token = TOKEN)
    bot = Telegram::Bot::Client.new(token.strip)

    while
      current_time = Time.now.to_s.split[1].split(":")[..1]
      schedule_time = SETTINGS[:time_to_send].map { |t| t.split(':') }

      if schedule_time.include?(current_time)
        AdminMessages.send_all_requests(bot)
      end

      sleep 58
    end
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


  