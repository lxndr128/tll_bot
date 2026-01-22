class ProcessMessage
  include Texts

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
      @caption = message.caption
      @media_group_id = message.media_group_id
      tg_id = message.chat.id
      username = message.chat.username || "Noname"
    end

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
        return { text: "✅ Режим модератора активирован.", chat_id: @user.tg_id, reply_keyboard: true, disable_reset_button: true }
      else 
        $logger.info("not admin")
        return { text: "✅ Режим обычного пользователя активирован.", chat_id: @user.tg_id, remove_keyboard: true, disable_reset_button: true }
      end
    end

    if SETTINGS[:moderators_ids].include?(@user.tg_id) && @user.admin
      if @message.start_with?("paginate_")
        return paginate_response
      end

      case @message
      when "📨 Заявки"
        return applications_response
      when "❓ Вопросы"
        return questions_response
      when "Необработанные заявки"
        return unprocessed_applications_response
      when "Необработанные вопросы"
        return unprocessed_questions_response
      when "🔙 Обычный режим"
        @user.update(admin: false)
        return { 
          text: "✅ Режим обычного пользователя активирован.", 
          chat_id: @user.tg_id,
          remove_keyboard: true,
          disable_reset_button: true 
        }
      end
      
      return AdminMessages.new(@message, @user, @bot).process
    end

    return unless border
    
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
    
    if @media_group_id
      message_key = "#{@user.tg_id}_#{@media_group_id}"
      if $processed_media_groups && $processed_media_groups[message_key]
        return false
      end
      $processed_media_groups ||= {}
      $processed_media_groups[message_key] = true
    end
    
    if @message == ($previous_message[@user.tg_id] || nil) && @photos.blank?
      return false
    end

    $previous_message[@user.tg_id] = @message

    return true if !@photos.blank?

    true
  end

  def applications_response
    Thread.new do
      sleep 0.5
      AdminMessages.send_applications_with_pagination(@bot, @user.tg_id, page: 1, per_page: 5)
    end
    
    with_moderator_menu("📨 Загружаю заявки (пагинация по 5 на страницу)...")
  end

  def questions_response
    Thread.new do
      sleep 0.5
      AdminMessages.send_questions_with_pagination(@bot, @user.tg_id, page: 1, per_page: 5)
    end
    
    with_moderator_menu("❓ Загружаю вопросы (пагинация по 5 на страницу)...")
  end

  def unprocessed_applications_response
    Thread.new do
      sleep 0.5
      AdminMessages.send_unprocessed_applications_with_pagination(@bot, @user.tg_id, page: 1, per_page: 5)
    end
    
    with_moderator_menu("🔄 Загружаю необработанные заявки...")
  end

  def unprocessed_questions_response
    Thread.new do
      sleep 0.5
      AdminMessages.send_unprocessed_questions_with_pagination(@bot, @user.tg_id, page: 1, per_page: 5)
    end
    
    with_moderator_menu("🔄 Загружаю необработанные вопросы...")
  end

  def paginate_response    
    parts = @message.split('_')

    if parts[1] == "info"
      return nil
    end

    type = parts[1]
    page = parts[2].to_i
    per_page = parts[3]&.to_i || 5

    page = [page, 1].max
    
    case type
    when "applications"
      AdminMessages.send_applications_with_pagination(@bot, @user.tg_id, page: page, per_page: per_page)
    when "questions"
      AdminMessages.send_questions_with_pagination(@bot, @user.tg_id, page: page, per_page: per_page)
    when "unprocessedq"
      AdminMessages.send_unprocessed_questions_with_pagination(@bot, @user.tg_id, page: page, per_page: per_page)
    when "unprocesseda"
      AdminMessages.send_unprocessed_applications_with_pagination(@bot, @user.tg_id, page: page, per_page: per_page)
    end

    return nil
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
    text_to_save = @caption.presence || @message
    
    if text_to_save.blank? || text_to_save == 'null'
      return { 
        text: "📝 Пожалуйста, отправьте текст анонса.", 
        chat_id: @user.tg_id,
        disable_reset_button: true
      }
    end
    
    @user.behalf!
    message_id = @m.try(:message_id) || Time.now.to_i
    application = Application.find_or_create_by(ready: false, user_id: @user.id, message_id: message_id)
    application.update(text: text_to_save)

    if @photos.present?
      save_best_photo(application)
    end

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
    if @photos
      process_photos
      
      return { text: photos_received_text, chat_id: @user.tg_id, buttons: [button_have_no_photos], disable_reset_button: true }
    end
    
    if @message == button_have_no_photos
      app = @user.applications.where(ready: false).last
      app.update(ready: true) if app
      @user.back_to_start!

      return { text: announce_have_sent_text, chat_id: @user.tg_id, disable_reset_button: true }
    end
    
    nil
  end

  def confirmation_response
    { text: proceed_text, chat_id: @user.tg_id, buttons: [button_send, button_rewrite] }
  end

  def process_photos
    return unless @photos.present? && @photos.last

    application = @user.applications.where(ready: false).last
    return unless application
    
    save_best_photo(application)
  end

  def save_best_photo(application)
    return unless @photos.present?
    
    best_photo = @photos.max_by { |p| p.file_size || 0 }
    
    if best_photo.file_id
      application.photos.create(file_id: best_photo.file_id)
    end
  end

  def reset_all
    @user.questions.where(ready: false).destroy_all
    @user.applications.where(ready: false).destroy_all
    @user.back_to_start! if @user.persisted?
  end

  def with_moderator_menu(text)
    return { text: text, chat_id: @user.tg_id, disable_reset_button: true } unless @user.admin
    
    { 
      text: text, 
      chat_id: @user.tg_id,
      reply_keyboard: true,
      disable_reset_button: true 
    }
  end
end