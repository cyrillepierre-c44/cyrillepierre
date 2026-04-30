class ContactMailer < ApplicationMailer
  def new_contact(name:, email:, company:, phone:, themes:, summary:, history:, precision: nil)
    @name      = name
    @email     = email
    @company   = company
    @phone     = phone
    @themes    = themes
    @summary   = summary
    @precision = precision
    @history   = parse_history(history)

    mail(
      to:       "cyrille.pierre@gmail.com",
      reply_to: email,
      subject:  "[cyrillepierre.fr] Nouveau contact — #{themes.join(' · ')} — #{name}"
    )
  end

  def confirmation_to_client(name:, email:, themes:, summary:)
    @name    = name
    @themes  = themes
    @summary = summary

    mail(
      to:      email,
      subject: "Votre demande a bien été reçue — Cyrille PIERRE"
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
