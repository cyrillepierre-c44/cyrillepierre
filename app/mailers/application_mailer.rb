class ApplicationMailer < ActionMailer::Base
  default from: -> { "Cyrille PIERRE <#{ENV['GMAIL_USERNAME']}>" }
  layout "mailer"
end
