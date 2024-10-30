require_relative './config'
require 'fallen'

module Bot
  extend Fallen
  
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

Bot.daemonize!
Bot.start!


  