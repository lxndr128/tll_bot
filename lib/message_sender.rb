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

    buttons = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)#, one_time_keyboard: true)
    @bot.api.send_message(chat_id: @chat_id, text: @text, reply_markup: buttons)
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