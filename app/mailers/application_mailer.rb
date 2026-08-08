class ApplicationMailer < ActionMailer::Base
  default from: -> { "Cyrille PIERRE <#{ENV.fetch('GMAIL_USERNAME', nil)}>" }
  layout "mailer"
end
