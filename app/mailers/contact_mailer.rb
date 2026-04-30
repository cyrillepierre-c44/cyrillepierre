class ContactMailer < ApplicationMailer
  def new_contact(name:, email:, company:, phone:, themes:, summary:, history:)
    @name    = name
    @email   = email
    @company = company
    @phone   = phone
    @themes  = themes
    @summary = summary
    @history = parse_history(history)

    mail(
      to:       "cyrille.pierre@gmail.com",
      reply_to: email,
      subject:  "[cyrillepierre.fr] Nouveau contact — #{themes.join(' · ')} — #{name}"
    )
  end

  private

  def parse_history(history)
    return [] if history.blank?
    JSON.parse(history)
  rescue JSON::ParserError
    []
  end
end
