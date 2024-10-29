require_relative './config'

def run_bot!(token = TOKEN)
  Telegram::Bot::Client.run(token) do |bot|
    bot.listen { |m| Sender.new(bot, ProcessMessage.new(m).process) }
  end
end

run_bot!