class ProcessMessage
  include Texts

  # Написать нормально, если будут силы
  def initialize(message, bot=nil)
    @bot = bot
    @m = message
    if message.class == Telegram::Bot::Types::CallbackQuery
      if message.respond_to?(:from)
        @message = message.data
        tg_id = message.from.id
        username = message.from.username || "Noname"
      else
        @message = message.data
        tg_id = message.message.chat.id
        username = message.message.chat.username || "Noname"
      end
    else
      @message = message.text || 'null'
      @photos = message.photo
      tg_id = message.chat.id
      username = message.chat.username || "Noname"
    end

    # Use find first, then create if not exists to avoid race conditions
    @user = User.find_by(tg_id: tg_id)
    unless @user
      begin
        @user = User.create!(tg_id: tg_id, username: username)
      rescue ActiveRecord::RecordNotUnique
        @user = User.find_by(tg_id: tg_id)
      end
    end
    unless @user
      msg = "Failed to find or create user with tg_id=#{tg_id}"
      $logger.error(msg) if defined?($logger)
      raise msg
    end
  end

  def process 
    if @message == "сменить режим" && SETTINGS[:moderators_ids].include?(@user.tg_id)
      @user.update(admin: !@user.admin)
      @user.questions.where(ready: false).destroy_all
      @user.applications.where(ready: false).destroy_all

      if @user.admin
        $logger.info("admin")
        return { text: "✅ Режим модератора активирован.", chat_id: @user.tg_id }
      else 
        $logger.info("not admin")
        return { text: "✅ Режим обычного пользователя активирован.", chat_id: @user.tg_id }
      end
    end

    return unless border
    return AdminMessages.new(@message, @user, @bot).process if SETTINGS[:moderators_ids].include?(@user.tg_id) && @user.admin
    
    reset_all if @message == button_reset_all

    begin
      self.send(@user.aasm_state + '_response')
    rescue => e
      $logger.error("Error processing message for user #{@user.tg_id}: #{e.class} - #{e.message}")
      $logger.error(e.backtrace.join("\n"))
      { text: "Произошла ошибка при обработке сообщения. Попробуй ещё раз.", chat_id: @user.tg_id }
    end
  end

  def border
    return if @m.try(:from).class.name != "Telegram::Bot::Types::User"
    
    # Skip duplicate messages (unless they contain photos)
    if @message == ($previous_message[@user.tg_id] || nil) && @photos.blank?
      return false
    end
    
    $previous_message[@user.tg_id] = @message

    # Allow photos in any state
    return true if !@photos.blank?

    true
  end

  def init_response
    case @message
    when button_announce
      @user.announce!

      { text: announce_text, chat_id: @user.tg_id }
    when button_question
      @user.question!
      
      { text: request_text, chat_id: @user.tg_id }
    else
      { text: announce_or_request_text, chat_id: @user.tg_id, buttons: [button_announce, button_question], disable_reset_button: true }
    end
  end

  def announce_response
    # User sends the announcement text
    @user.behalf!
    message_id = @m.try(:message_id) || Time.now.to_i
    application = Application.find_or_create_by(ready: false, user_id: @user.id, message_id: message_id)
    application.update(text: @message)

    { text: on_whose_behalf_text, chat_id: @user.tg_id, buttons: [button_tll_event, button_other_event], disable_reset_button: true }
  end

  def other_question_response
    message_id = @m.try(:message_id) || Time.now.to_i
    question = Question.find_or_create_by(ready: false, user_id: @user.id, message_id: message_id)
    question.update(text: @message, ready: true)
    @user.back_to_start!

    { text: request_have_sent_text, chat_id: @user.tg_id, disable_reset_button: true }
  end


  def on_whose_behalf_response
    case @message
    when button_tll_event
      @user.commercial!
      app = @user.applications.where(ready: false).last
      app.update(as_tll: true) if app

      { text: about_commercial_text, chat_id: @user.tg_id, disable_reset_button: true  }
    when button_other_event
      @user.commercial!
      app = @user.applications.where(ready: false).last
      app.update(as_tll: false) if app

      { text: about_commercial_text, chat_id: @user.tg_id, disable_reset_button: true }
    else
      { text: on_whose_behalf_text, chat_id: @user.tg_id, buttons: [button_tll_event, button_other_event], disable_reset_button: true }
    end
  end

  def commercial_or_not_response
    @user.ask_for_resources!
    # Use the last unfinished application (preserves text from announce_description_response)
    application = @user.applications.where(ready: false).last
    application.update(commercial: @message) if application

    { text: ask_for_resources_text, chat_id: @user.tg_id, disable_reset_button: true }
  end

  def resources_response
    @user.add_photos!
    application = @user.applications.where(ready: false).last
    application.update(resources: @message) if application

    { text: ask_for_photo_text, chat_id: @user.tg_id, buttons: [button_have_no_photos] }
  end

  def photos_response
    # Process incoming photos
    if @photos
      process_photos
      
      # Send confirmation but stay in photos state to allow more photos
      return { text: photos_received_text, chat_id: @user.tg_id, buttons: [button_have_no_photos], disable_reset_button: true }
    end
    
    # If user sends text message in photos state (without photos) - button press to finish
    if @message == button_have_no_photos
      app = @user.applications.where(ready: false).last
      app.update(ready: true) if app
      @user.back_to_start!

      return { text: announce_have_sent_text, chat_id: @user.tg_id, disable_reset_button: true }
    end
    
    # Any other text message - stay in photos state
    nil
  end

  def confirmation_response
    { text: proceed_text, chat_id: @user.tg_id, buttons: [button_send, button_rewrite] }
  end

  def process_photos
    return unless @photos.present? && @photos.last

    application = @user.applications.where(ready: false).last
    return unless application
    
    application.photos.create(file_id: @photos.last.file_id) if @photos.last.file_id
  end

  def reset_all
    @user.questions.where(ready: false).destroy_all
    @user.applications.where(ready: false).destroy_all
    @user.back_to_start! if @user.persisted?
  end
end
