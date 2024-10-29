class ProcessMessage
  def initialize(message)
    @user = User.find_or_create_by(tg_id: message.chat.id)
    @message = message.text
  end

  def process
    case @user.state
    when :init then request_or_application_response
    end
  end

  def request_or_application_response
    announce_or_request_text = TEXTS[:announce_or_request]
    announce_text = TEXTS[:about_announce_text]
    request_text = TEXTS[:write_your_request]

    button_announce = TEXTS[:buttons][:announce_event]
    button_question = TEXTS[:buttons][:other_question]

    case @message
    when button_announce
      @user.announce
      { text: announce_text, chat_id: @user.tg_id }
    when button_question
      @user.question
      { text: request_text, chat_id: @user.tg_id }
    else
      { text: announce_or_request_text, chat_id: @user.tg_id, buttons: [button_announce, button_question] }
    end
  end
end
