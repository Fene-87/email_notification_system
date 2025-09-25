defmodule EmailNotificationSystem.Fixtures do
  alias EmailNotificationSystem.{Repo}
  alias EmailNotificationSystem.Accounts.User
  alias EmailNotificationSystem.Contacts.Contact

  def user_fixture(attrs \\ %{}) do
    base = %{
      first_name: "Ada",
      last_name: "Lovelace",
      email_address: "ada#{System.unique_integer()}@example.com",
      msisdn: "+2547#{Enum.random(10000000..99999999)}",
      password: "verysecret"
    }

    {:ok, user} =
      %User{}
      |> User.registration_changeset(Map.merge(base, attrs))
      |> Repo.insert()

    user
  end

  def contact_fixture(user, attrs \\ %{}) do
    base = %{
      first_name: "Linus",
      last_name: "Torvalds",
      email_address: "linus#{System.unique_integer()}@example.com",
      phone_number: "0712345678",
      user_id: user.id
    }

    {:ok, contact} =
      %Contact{}
      |> Contact.changeset(Map.merge(base, attrs))
      |> Repo.insert()

    contact
  end
end
