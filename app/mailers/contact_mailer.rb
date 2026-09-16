class ContactMailer < ApplicationMailer
  INTERNAL_ALERT_TO = "cyrille.pierre@gmail.com".freeze

  def new_contact(name:, email:, company:, phone:, themes:, summary:, history:, precision: nil, sector: nil, size: nil)
    @name      = name
    @email     = email
    @company   = company
    @phone     = phone
    @themes    = themes
    @summary   = summary
    @precision = precision
    @history   = parse_history(history)
    @sector    = sector
    @size      = size

    # Alerte interne : directement sur la boîte, pas via contact@. L'alias ferait faire au mail un
    # aller-retour par Cloudflare pour revenir dans la même boîte, et Gmail déduplique un message
    # qu'il a lui-même envoyé — l'alerte pourrait ne jamais apparaître en réception.
    mail(
      to: INTERNAL_ALERT_TO,
      reply_to: email,
      subject: "[cyrillepierre.com] Nouveau contact — #{themes.join(' · ')} — #{name}"
    )
  end

  def confirmation_to_client(name:, email:, themes:, summary:)
    @name    = name
    @themes  = themes
    @summary = summary

    mail(
      to: email,
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
