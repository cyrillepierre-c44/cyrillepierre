# Le premier message à un décideur, envoyé depuis contact@ en texte brut : un dirigeant lit un
# mail court de quelqu'un qu'il ne connaît pas comme un mail, pas comme une lettre d'information.
# Le pied rappelle l'origine publique de l'approche et la façon de la refuser (prospection B2B).
class OutreachMailer < ApplicationMailer
  def first_contact(generation)
    @generation = generation
    @body = generation.email_body

    mail(to: generation.prospect.email, reply_to: SiteIdentity::EMAIL, subject: generation.email_subject)
  end
end
