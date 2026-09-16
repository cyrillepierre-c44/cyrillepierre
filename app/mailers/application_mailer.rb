class ApplicationMailer < ActionMailer::Base
  # L'adresse du domaine, pas celle du compte Gmail qui sert de serveur SMTP. Gmail ne conserve
  # cet expéditeur que parce que contact@ est un alias vérifié du compte (« Envoyer des e-mails
  # en tant que ») : si l'alias disparaît, Gmail réécrit silencieusement l'expéditeur vers
  # l'adresse du compte, sans erreur.
  SENDER = "Cyrille PIERRE <contact@cyrillepierre.com>".freeze

  default from: SENDER
  layout "mailer"
end
