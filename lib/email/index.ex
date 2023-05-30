defmodule Rivet.Email do
  @moduledoc """
  send(recips, template)
  send(recips, template, assigns)

  For each good recipient call template.format(%@email_model{}, assigns),
  where email.user is preloaded on %@email_model{}

  - `recips` can be one or list of: user id, a `user_model`, or a `email_model`
  - `assigns` (optional) is a dictionary with key/value attributes to use in the template

  Returns a tuple of :ok or :error with a list of results from each send.
  It will stop at the first error, however, and not continue.
  """

  def mailer(), do: Application.get_env(:rivet_email, :mailer)

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @user_model Keyword.get(opts, :user_model, Rivet.Ident.User)
      @email_model Keyword.get(opts, :email_model, Rivet.Ident.Email)
      @site_key Keyword.get(opts, :rivet_email_data, :rivet_email_data)
      @backend Keyword.get(opts, :backend)
      require Logger

      @type email_model() :: @email_model.t()
      @type user_model() :: @user_model.t()
      @type user_id() :: String.t()
      @type email_recipient() :: email_model() | user_model() | user_id()

      def send(recips, template, assigns \\ []) do
        with {:ok, emails} <- get_emails(recips),
             {:ok, assigns} <- generate_assigns(assigns) do
          send_all(emails, template, assigns, [])
        end
      end

      ##########################################################################
      defp send_all([recip | rest], template, assigns, out) when is_map(assigns) do
        case deliver(recip, template, assigns) do
          {:ok, result} -> send_all(rest, template, assigns, [result | out])
          error -> {:error, error, [out] |> Enum.reverse()}
        end
      end

      defp send_all([], _, _, out), do: {:ok, Enum.reverse(out)}

      ##########################################################################
      defp generate_assigns(assigns) do
        assigns = Map.new(assigns) |> Map.put(:site, Application.get_env(:rivet_email, :site))

        case Map.get_lazy(assigns, :email_from, fn -> get_in(assigns, [:site, :email_from]) end) do
          nil -> {:error, ":email_from missing"}
          [name, email] -> {:ok, Map.put(assigns, :email_from, {name, email})}
          from -> {:ok, Map.put(assigns, :email_from, from)}
        end
      end

      ##########################################################################
      @spec deliver(recipient :: any(), template :: atom(), assigns :: map()) ::
              {:ok, Swoosh.Email.t()} | {:error, term()}
      def deliver(%@email_model{} = recipient, template, assigns) do
        case template.generate(recipient, assigns) do
          {:ok, subject, body} ->
            Swoosh.Email.new(to: recipient.address, from: assigns.email_from)
            |> Swoosh.Email.subject(subject)
            |> Swoosh.Email.html_body("<html><body>#{body}</body></html>")
            |> Swoosh.Email.text_body(Rivet.Email.Template.html2text(body))
            |> send_email()

          other ->
            Logger.debug("error processing template", error: other)
            IO.inspect(other)
            {:error, :invalid_template_result}
        end
      end

      ##########################################################################
      def send_email(%Swoosh.Email{to: [{_, eaddr} = addr], subject: subj} = email) do
        if Application.get_env(:rivet_email, :enabled) do
          if String.ends_with?("@example.com", eaddr) do
            {:error, :example_email}
          else
            Logger.debug("sending email", to: eaddr, from: email.from, subject: subj)
            @backend.deliver(email)
          end
        else
          Logger.warn("Email disabled, not sending message to #{inspect(addr)}", subject: subj)
          log_email(email)
          {:ok, "email disabled"}
        end
      end

      ##########################################################################
      def log_email(%Swoosh.Email{} = email) do
        Logger.warning("""
        Subject: #{email.subject}
        --- html
        #{email.html_body}
        --- text
        #{email.text_body}
        """)
      end

      ##########################################################################
      # future: assigns can include verfied: true (or some way to only send to verified addresses)
      @spec get_emails(email_recipient() | list(email_recipient)) ::
              {:ok, list(email_model())} | {:error, String.t(), term()}

      def get_emails(recip, out \\ [])

      def get_emails([recip | recips], out) do
        with {:ok, email} <- get_email(recip) do
          get_emails(recips, [email | out])
        else
          {:error, %{reason: :no_email, user: user}} ->
            {:error, "Unable to load email for user, cannot send email", user: user.id}

          err ->
            {:error, "Unable to find email", err}
        end
      end

      def get_emails([], out), do: {:ok, out}
      def get_emails(recip, out), do: get_emails([recip], out)

      ##########################################################################
      @spec get_email(email_recipient()) :: {:ok, email_model()} | {:error, reason :: any()}
      defp get_email(%@email_model{} = email) do
        with {:ok, %@email_model{} = email} <- @email_model.preload(email, :user) do
          {:ok, email}
        end
      end

      # TODO: verified should be a settable option
      defp get_email(%@user_model{} = user) do
        with {:ok, %@user_model{emails: emails}} <- @user_model.preload(user, :emails) do
          case Enum.find(emails, fn e -> e.verified end) do
            %@email_model{} = email ->
              {:ok, %@email_model{email | user: user}}

            _ ->
              with %@email_model{} = email <- List.first(emails) do
                {:ok, %@email_model{email | user: user}}
              else
                _ ->
                  {:error, :no_email}
              end
          end
        end
      end

      defp get_email(user_id) when is_binary(user_id) do
        with {:ok, user} <- @user_model.one(user_id) do
          get_email(user)
        end
      end
    end
  end
end
