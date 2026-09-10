# Gmail laisse parfois la poignée de main SMTP en suspens : le 10/09/2026, la confirmation
# envoyée à une visiteuse a été perdue sur un Net::ReadTimeout dans `do_start`, sans reprise.
# Elle avait pourtant vu « votre demande a bien été envoyée ».
#
# Les erreurs réseau sont retentées, jamais les erreurs définitives (authentification,
# destinataire invalide) : les rejouer ne ferait que retarder le diagnostic.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  RETRYABLE_NETWORK_ERRORS = [
    Net::ReadTimeout, Net::OpenTimeout, Net::SMTPServerBusy,
    IOError, EOFError, Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::EPIPE, SocketError
  ].freeze

  retry_on(*RETRYABLE_NETWORK_ERRORS, wait: :polynomially_longer, attempts: 5)
end
