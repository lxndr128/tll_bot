class Sender
  include Texts

  def initialize(bot, result)
    result = {} unless result

    @bot = bot
    @text = result[:text]
    @chat_id = result[:chat_id]
    @buttons = result[:buttons] || []
    @disable_reset_button = result[:disable_reset_button]
    @photos = result[:photos]

    send
    send_bunch_of_photos if @photos
  end

  def send
    return if @chat_id.nil?

    @buttons << button_reset_all unless @disable_reset_button
    return send_text_and_buttons unless @buttons.blank?
    
    send_text
  end

  def send_text
    @bot.api.send_message(chat_id: @chat_id, text: @text)
  end

  def send_text_and_buttons
    #kb = [ @buttons.map { |b| { text: b } } ]
    kb = [ @buttons.map { |b| Telegram::Bot::Types::InlineKeyboardButton.new(text: b, callback_data: b) } ]
    buttons = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)#, one_time_keyboard: true)
    @bot.api.send_message(chat_id: @chat_id, text: @text, reply_markup: buttons)
  end

  def send_bunch_of_photos
    media = @photos.map { |id| Telegram::Bot::Types::InputMediaPhoto.new({media: id}) }
    bot.api.send_media_group(chat_id: @chat_id, media: media)
  end
end