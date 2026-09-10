require "test_helper"

class MailDeliveryJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def delivering(error)
    mail = Object.new
    # Certaines de ces classes exigent un message à la construction (Net::SMTPServerBusy) :
    # on instancie explicitement plutôt que de laisser `raise` le faire.
    mail.define_singleton_method(:deliver_now) do
      raise(error.is_a?(Class) ? error.new("panne réseau simulée") : error)
    end
    ContactMailer.stub(:new_contact, ->(*) { mail }) do
      yield MailDeliveryJob.new("ContactMailer", "new_contact", "deliver_now", args: [])
    end
  end

  test "the app delivers mail through the retrying job" do
    assert_equal MailDeliveryJob, ActionMailer::Base.delivery_job
  end

  test "a network hiccup on Gmail is retried instead of losing the mail" do
    delivering(Net::ReadTimeout) do |job|
      assert_enqueued_with(job: MailDeliveryJob) { job.perform_now }
    end
  end

  test "every network error we saw in production is covered" do
    MailDeliveryJob::RETRYABLE_NETWORK_ERRORS.each do |error|
      delivering(error) do |job|
        assert_enqueued_with(job: MailDeliveryJob) { job.perform_now }
      end
    end
  end

  test "a permanent failure is raised rather than retried forever" do
    delivering(Net::SMTPAuthenticationError.new("535 auth failed")) do |job|
      assert_no_enqueued_jobs do
        assert_raises(Net::SMTPAuthenticationError) { job.perform_now }
      end
    end
  end
end
