defmodule EmailNotificationSystem.EmailsTest do
  use EmailNotificationSystem.DataCase
  alias EmailNotificationSystem.{Emails}
  alias EmailNotificationSystem.Emails.EmailRecipient
  import EmailNotificationSystem.Fixtures
  use Oban.Testing, repo: EmailNotificationSystem.Repo

  test "send_email/2 inserts recipients, queues job, and sets status queued" do
    user = user_fixture()
    c1 = contact_fixture(user)
    {:ok, email} =
      Emails.create_email(%{
        user_id: user.id,
        subject: "Hello",
        body: "<p>Hi</p>",
        from_email: user.email_address,
        email_type: "single",
        priority: 5
      })

    {:ok, email} = Emails.send_email(email, [c1])

    # status updated
    assert email.status == "queued"

    # recipient inserted
    recips = EmailNotificationSystem.Repo.all(EmailRecipient)
    assert length(recips) == 1
    [r] = recips
    assert r.recipient_email == c1.email_address
    assert r.status == "pending"

    # job enqueued
    assert_enqueued worker: EmailNotificationSystem.Workers.EmailWorker, args: %{email_id: email.id}
  end
end
