class AdminMessages
  extend Texts

  class << self
    def send_all_requests(bot, chat_id=nil)
      Application.where(processed: false, ready: true).each do |a|
        Sender.new(bot, AdminMessages.notification(a, chat_id))
      end

      Question.where(processed: false, ready: true).each do |q|
        Sender.new(bot, AdminMessages.notification(q, chat_id))
      end
    end

    def notification(r, chat_id=nil)
      buttons = [button_resolve(r), button_send_full(r)]
      { text: short_text(r), chat_id: chat_id || SETTINGS[:admin_group_id], c_buttons: buttons, disable_reset_button: true }
    end

    def short_text(r)
      r.text[..50].strip + "...\n" + "@#{r.user.username}"
    end

    def button_resolve(r)
      [button_resolve_request, "resolve_#{r.class}_#{r.id}" ]
    end

    def button_send_full(r)
      [button_send_full_request, "sendfull_#{r.class}_#{r.id}" ]
    end
  end

  def initialize(message_text, user, bot=nil)
    arr = message_text.split('_')
    @bot = bot
    @command = arr[0]
    @class = arr[1]
    @id = arr[2]
    @user = user
  end

  def process
    self.send(@command + '_response', @class, @id)
  end

  def sendall_response(klass, id)
    self.class.send_all_requests(@bot, @user.tg_id)
    nil
  end

  def resolve_response(klass, id)
    klass.constantize.find(id).update(processed: true, processed_by: @user.id)
    nil
  end

  def sendfull_response(klass, id)
    return sendfull_question_response(id) if klass == "Question"

    sendfull_application_response(id)
  end

  def sendfull_application_response(id)
    a = Application.find(id)
    as_tll = a.as_tll ? "да" : "нет"
    response = "Заявка: \n\n"
    response += a.text + "\n\n"
    response += "От лица ТЛЛ?: " + as_tll + "\n\n"
    response += "Коммерция?: " + as_tll + "\n\n"
    response += "От кого: " + "@#{a.user.username}"
    response += "\n\nФотографии ниже:" if a.photos.any?

    buttons = [self.class.button_resolve(a)]

    { text: response, chat_id: @user.tg_id, c_buttons: buttons, photos: a.photos, disable_reset_button: true }
  end

  def sendfull_question_response(id)
    q = Question.find(id)
    response = "Вопрос:\n\n"
    response += q.text + "\n\n"
    response += "От кого: " + "@#{q.user.username}"

    buttons = [self.class.button_resolve(q)]

    { text: response, chat_id: @user.tg_id, c_buttons: buttons, disable_reset_button: true }
  end

  def method_missing(a,b,c)
    nil
  end
end