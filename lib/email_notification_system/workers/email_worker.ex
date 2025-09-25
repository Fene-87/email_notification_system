defmodule EmailNotificationSystem.Workers.EmailWorker do
  use Oban.Worker, queue: :emails, max_attempts: 3

  import Ecto.Query

  alias EmailNotificationSystem.{Repo, Emails, Mailer}
  alias EmailNotificationSystem.Emails.EmailRecipient

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email_id" => email_id} = args}) do
    # Preloads :user per your Emails.get_email!/1
    email = Emails.get_email!(email_id)

    case args do
      %{"retry" => true} -> handle_retry_email(email)
      _ -> handle_send_email(email)
    end
  end

  # ---- normal send path ----
  defp handle_send_email(email) do
    Emails.update_email(email, %{status: "sending"})
    notify(email, :sending)

    recipients =
      from(er in EmailRecipient,
        where: er.email_id == ^email.id and er.status == "pending"
      )
      |> Repo.all()

    results = Enum.map(recipients, &send_to_recipient(email, &1))
    finalize_email_status(email, results)
    :ok
  end

  defp notify(email, event) do
    Phoenix.PubSub.broadcast(
      EmailNotificationSystem.PubSub,
      "emails:#{email.user_id}",
      {:email_event, event, email.id}
    )
  end

  defp handle_retry_email(email) do
    handle_send_email(email)
  end

  defp finalize_email_status(email, results) do
    final_status = if Enum.all?(results, &(&1 == :ok)), do: "sent", else: "failed"
    now = DateTime.truncate(DateTime.utc_now(), :second)

    Emails.update_email(email, %{status: final_status, sent_at: now})

    # Let the EmailsLive page refresh itself
    Phoenix.PubSub.broadcast(
      EmailNotificationSystem.PubSub,
      "emails:#{email.user_id}",
      {:email_updated, email.id}
    )
  end

  # ---- helper that actually sends one message ----
  defp send_to_recipient(email, recipient) do
    # Build a reasonable sender display name from the user
    sender_name =
      [email.user.first_name, email.user.last_name]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> String.trim()

    try do
      swoosh_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to({recipient.recipient_name, recipient.recipient_email})
        |> Swoosh.Email.from({sender_name == "" && email.from_email || sender_name, email.from_email})
        |> Swoosh.Email.subject(email.subject)
        |> Swoosh.Email.html_body(email.body)

      swoosh_email =
        case email.reply_to do
          nil -> swoosh_email
          "" -> swoosh_email
          reply -> Swoosh.Email.reply_to(swoosh_email, reply)
        end

      case Mailer.deliver(swoosh_email) do
        {:ok, _resp} ->
          update_recipient_status(recipient, "sent", %{sent_at: DateTime.truncate(DateTime.utc_now(), :second)})
          :ok

        {:error, reason} ->
          update_recipient_status(recipient, "failed", %{
            error_message: inspect(reason),
            retry_count: recipient.retry_count + 1
          })

          :error
      end
    rescue
      e ->
        update_recipient_status(recipient, "failed", %{
          error_message: Exception.message(e),
          retry_count: recipient.retry_count + 1
        })

        :error
    end
  end

  defp update_recipient_status(recipient, status, additional_attrs \\ %{}) do
    attrs = Map.put(additional_attrs, :status, status)

    recipient
    |> EmailRecipient.changeset(attrs)
    |> Repo.update()
  end
end
