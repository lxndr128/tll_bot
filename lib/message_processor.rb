class ProcessMessage
  include Texts

  def initialize(message)
    if message.class == Telegram::Bot::Types::CallbackQuery
      @message = message.data
      @user = User.find_or_create_by(tg_id: message.message.chat.id)
    else
      @message = message.text || 'null'
      @photos = message.photo
      @user = User.find_or_create_by(tg_id: message.chat.id)
    end
  end

  def process
    return if @message == $previous_message[@user.tg_id]

    $previous_message[@user.tg_id] = @message

    return if !@photos.blank? && @user.aasm_state != "photos"

    reset_all if @message == button_reset_all

    self.send(@user.aasm_state + '_response')
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

  def other_question_response
    question = Question.find_or_create_by(ready: false, user_id: @user.id)
    question.update(text: @message, ready: true)
    @user.back_to_start!

    { text: request_have_sent_text, chat_id: @user.tg_id, disable_reset_button: true }
  end

  def announce_description_response
    @user.behalf!
    application = Application.find_or_create_by(ready: false, user_id: @user.id)
    application.update(text: @message)

    { text: on_whose_behalf_text, chat_id: @user.tg_id, buttons: [button_tll_event, button_other_event], disable_reset_button: true }
  end

  def on_whose_behalf_response
    case @message
    when button_tll_event
      @user.commercial!
      @user.applications.where(ready: false).last.update(as_tll: true)

      { text: about_commercial_text, chat_id: @user.tg_id }
    when button_other_event
      @user.commercial!
      @user.applications.where(ready: false).last.update(as_tll: true)

      { text: about_commercial_text, chat_id: @user.tg_id }
    else
      { text: on_whose_behalf_text, chat_id: @user.tg_id, buttons: [button_tll_event, button_other_event], disable_reset_button: true }
    end
  end

  def commercial_or_not_response
    @user.add_photos!
    application = Application.find_or_create_by(ready: false, user_id: @user.id)
    application.update(commercial: @message)

    { text: ask_for_photo_text, chat_id: @user.tg_id, buttons: [button_have_no_photos] }
  end

  def photos_response
    process_photos
    return if @message == 'null'

    @user.applications.where(ready: false).last.update(ready: true)
    @user.back_to_start!

    { text: announce_have_sent_text, chat_id: @user.tg_id, disable_reset_button: true }
  end

  def confirmation_response
    { text: proceed_text, chat_id: @user.tg_id, buttons: [button_send, button_rewrite] }
  end

  def process_photos
    return unless @photos

    application = @user.applications.where(ready: false).last
    application.photos.create(file_id: @photos.last.file_id)
  end

  def reset_all
    @user.questions.where(ready: false).destroy_all
    @user.applications.where(ready: false).destroy_all
    @user.back_to_start!
  end
end
