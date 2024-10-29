class Sender
  def initialize(bot, result)
    @bot = bot
    @text = result[:text]
    @chat_id = result[:chat_id]
    @buttons = result[:buttons]

    send
  end

  def send
    return send_text_and_buttons if @buttons
    
    send_text
  end

  def send_text
    @bot.api.send_message(chat_id: @chat_id, text: @text)
  end

  def send_text_and_buttons
    kb = [ @buttons.map { |b| { text: b } } ]
    buttons = Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: kb, one_time_keyboard: true)
    @bot.api.send_message(chat_id: @chat_id, text: @text, reply_markup: buttons)
  end
end