class AdminMessages
  extend Texts

  class << self
    def send_all_requests(bot, chat_id=nil)
      # Throttle to prevent overwhelming the server - max 30 messages per run
      # with 100ms delay between each message
      sent_count = 0
      max_per_run = 30
      delay_ms = 100
      
      Application.where(processed: false, ready: true).limit(max_per_run).each do |a|
        break if sent_count >= max_per_run
        Sender.new(bot, AdminMessages.notification(a))
        sent_count += 1
        sleep(delay_ms / 1000.0)
      end

      Question.where(processed: false, ready: true).limit(max_per_run - sent_count).each do |q|
        break if sent_count >= max_per_run
        Sender.new(bot, AdminMessages.notification(q))
        sent_count += 1
        sleep(delay_ms / 1000.0)
      end
    end

    def send_all_requests_ls(bot, chat_id)
      # Throttle to prevent overwhelming the server - max 30 messages per run
      sent_count = 0
      max_per_run = 30
      delay_ms = 100
      
      Application.where(ready: true).where("created_at >= #{Date.today - 2.months}").order(created_at: :desc).limit(max_per_run).each do |a|
        break if sent_count >= max_per_run
        Sender.new(bot, AdminMessages.ls_notification(a, chat_id))
        sent_count += 1
        sleep(delay_ms / 1000.0)
      end

      Question.where(ready: true).where("created_at >= #{Date.today - 2.months}").order(created_at: :desc).limit(max_per_run - sent_count).each do |q|
        break if sent_count >= max_per_run
        Sender.new(bot, AdminMessages.ls_notification(q, chat_id))
        sent_count += 1
        sleep(delay_ms / 1000.0)
      end
    end

    def notification(r)
      buttons = [button_resolve(r), button_send_full(r)]
      { text: short_text(r), chat_id: SETTINGS[:admin_group_id], c_buttons: buttons, disable_reset_button: true }
    end

    def ls_notification(r, chat_id)
      buttons = [button_send_full_ls(r)]
      buttons << button_resolve(r) if r.processed == false
      { text: short_text(r), chat_id: chat_id, c_buttons: buttons, disable_reset_button: true }
    end

    def short_text(r)
      text = r.text.to_s[..50].to_s.strip
      text = text.empty? ? "(пусто)" : text
      username = r.user&.username || "unknown"
      text + "...\n" + "@#{username}"
    end

    def button_resolve(r)
      [button_resolve_request, "resolve_#{r.class}_#{r.id}" ]
    end

    def button_send_full(r)
      [button_send_full_request, "sendfull_#{r.class}_#{r.id}" ]
    end

    def button_send_full_ls(r)
      [button_send_full_request, "sendfullls_#{r.class}_#{r.id}" ]
    end
  end

  def initialize(message_text, user, bot=nil)
    arr = message_text.to_s.split('_')
    @bot = bot
    @command = arr[0]
    @class = arr[1]
    @id = arr[2]
    @user = user
  end

  def process
    # Pass the admin's chat id so response methods can reply to the correct chat
    self.send(@command + '_response', @class, @id, @user.tg_id)
  rescue => e
    $logger.error("Error processing admin message from #{@user.username}: #{e.class} - #{e.message}")
    $logger.error(e.backtrace.join("\n"))
    nil
  end

  def sendall_response(klass, id, chat_id = nil)
    # send list to the requesting admin chat (chat_id passed via process)
    self.class.send_all_requests_ls(@bot, chat_id || @user.tg_id)
    nil
  end
  def resolve_response(klass, id, chat_id = nil)
    resolvable = klass.constantize.find(id)
    resolvable.update(processed: true, processed_by: @user.id)

    req_text = resolvable.text.to_s[..35].to_s.strip
    text = "Заявка \"#{req_text}...\" была обработана админом #{@user.username}"

    target_chat = chat_id || SETTINGS[:admin_group_id]

    # Send confirmation to the target chat (admin's PM if invoked there)
    result = { text: text, chat_id: target_chat, disable_reset_button: true }

    # Additionally notify admin group if the action was performed from a private chat
    if target_chat != SETTINGS[:admin_group_id] && @bot
      begin
        Sender.new(@bot, { text: "Заявка \"#{req_text}...\" была обработана админом #{@user.username}", chat_id: SETTINGS[:admin_group_id], disable_reset_button: true })
      rescue => e
        $logger.error("Failed to notify admin group: #{e.class} - #{e.message}") if defined?($logger)
      end
    end

    result
  end

  def sendfull_response(klass, id, chat_id = nil)
    return sendfull_question_response(id, chat_id) if klass == "Question"

    sendfull_application_response(id, chat_id)
  end

  def sendfullls_response(klass, id, chat_id = nil)
    return sendfull_question_response(id, chat_id || @user.tg_id) if klass == "Question"

    sendfull_application_response(id, chat_id || @user.tg_id)
  end

  def sendfull_application_response(id, chat_id=nil)
    a = Application.find(id)
    return nil unless a
    
    buttons = []
    as_tll = a.as_tll ? "да" : "нет"
    response = "Заявка: \n\n"
    # If main text is empty but resources provided, show resources as main text
    main_text = a.text.to_s.strip
    if main_text.empty? && a.resources.present?
      main_text = "(основной текст пуст)\nЗапрос ресурсов: " + a.resources.to_s
    end
    response += main_text + "\n\n"
    response += "От лица ТЛЛ?: " + as_tll + "\n\n"
    response += "Коммерция?: " + a.commercial.to_s + "\n\n"
    # Include resources block if provided
    if a.resources.present?
      response += "Потребности / ресурсы: " + a.resources.to_s + "\n\n"
    end
    username = a.user&.username || "unknown"
    response += "От кого: " + "@#{username}"
    response += "\n\nФотографии ниже:" if a.photos.any?

    buttons = [self.class.button_resolve(a)] if a.processed == false

    { text: response, chat_id: chat_id || SETTINGS[:admin_group_id], c_buttons: buttons, photos: a.photos, disable_reset_button: true }
  end

  def sendfull_question_response(id, chat_id=nil)
    q = Question.find(id)
    return nil unless q
    
    buttons = []
    response = "Вопрос:\n\n"
    response += q.text.to_s + "\n\n"
    username = q.user&.username || "unknown"
    response += "От кого: " + "@#{username}"

    buttons = [self.class.button_resolve(q)] if q.processed == false

    { text: response, chat_id: chat_id || SETTINGS[:admin_group_id], c_buttons: buttons, disable_reset_button: true }
  end

  def method_missing(*_args)
    nil
  end
end