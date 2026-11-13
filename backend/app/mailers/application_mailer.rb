class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV["MAIL_FROM"].presence || ENV["SMTP_USERNAME"].presence || "bearwatch@localhost" }
end
