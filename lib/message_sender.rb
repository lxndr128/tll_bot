class Sender
  include Texts

  def initialize(bot, result)
    result = {} unless result

    @bot = bot
    @text = result[:text]
    @chat_id = result[:chat_id]
    @buttons = result[:buttons] || []
    @c_buttons = result[:c_buttons] || []
    @disable_reset_button = result[:disable_reset_button]
    @photos = result[:photos]
    @reply_keyboard = result[:reply_keyboard]
    @remove_keyboard = result[:remove_keyboard]

    send
    begin
      send_bunch_of_photos if @photos
    rescue => e
      $logger.error("Error sending photos to #{@chat_id}: #{e.class} - #{e.message}") if defined?($logger)
    end
  end

  def send
    return if @chat_id.nil?
    return if @text.nil? || @text.empty?

    # Отправка Reply Keyboard (постоянное меню)
    if @reply_keyboard
      return send_reply_keyboard
    end

    # Удаление клавиатуры
    if @remove_keyboard
      return remove_reply_keyboard
    end

    @buttons << button_reset_all unless @disable_reset_button
    begin
      return send_text_and_buttons if @buttons.present? || @c_buttons.present?
      
      send_text
    rescue => e
      $logger.error("Error sending message to #{@chat_id}: #{e.class} - #{e.message}")
      $logger.error(e.backtrace.join("\n"))
    end
  end

  def send_text
    @bot.api.send_message(chat_id: @chat_id, text: @text)
  end

  def send_text_and_buttons
    kb = []
    if @c_buttons.present?
      kb = [ @c_buttons.map { |t, d| Telegram::Bot::Types::InlineKeyboardButton.new(text: t, callback_data: d) } ]
    else
      kb = [ @buttons.map { |b| Telegram::Bot::Types::InlineKeyboardButton.new(text: b, callback_data: b) } ]
    end

    buttons = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
    @bot.api.send_message(chat_id: @chat_id, text: @text, reply_markup: buttons)
  end

  def send_reply_keyboard
    return if @chat_id.nil?
    return if @text.nil? || @text.empty?

    keyboard = [
      [Telegram::Bot::Types::KeyboardButton.new(text: "📨 Заявки"), 
      Telegram::Bot::Types::KeyboardButton.new(text: "❓ Вопросы")],
      [Telegram::Bot::Types::KeyboardButton.new(text: "🔄 Необработанные заявки"), 
      Telegram::Bot::Types::KeyboardButton.new(text: "⏳ Необработанные вопросы")],
      [Telegram::Bot::Types::KeyboardButton.new(text: "🔙 Обычный режим")]
    ]

    reply_markup = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: keyboard,
      resize_keyboard: true,
      one_time_keyboard: false
    )

    @bot.api.send_message(chat_id: @chat_id, text: @text, reply_markup: reply_markup)
  rescue => e
    $logger.error("Error sending reply keyboard to #{@chat_id}: #{e.class} - #{e.message}")
    $logger.error(e.backtrace.join("\n"))
  end

  def remove_reply_keyboard
    reply_markup = Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
    @bot.api.send_message(chat_id: @chat_id, text: @text, reply_markup: reply_markup)
  end

  def send_bunch_of_photos
    return unless @photos.respond_to?(:map)
    media = @photos.map { |p| Telegram::Bot::Types::InputMediaPhoto.new({media: p.file_id}) rescue nil }.compact
    return if media.empty?
    begin
      @bot.api.send_media_group(chat_id: @chat_id, media: media)
    rescue => e
      $logger.error("Error in send_media_group to #{@chat_id}: #{e.class} - #{e.message}") if defined?($logger)
    end
  end
end