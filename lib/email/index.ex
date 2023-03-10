defmodule Rivet.Email do
  @moduledoc """
  send(recip, template)
  send(recip, template, args)

  For each good recipient call template.format(%@email_model{}, args),
  where email.user is preloaded on %@email_model{}

  - `recip` can be one or list of: user id, a `user_model`, or a `email_model`
     (models are defined ...
  - `opts` (optional) is a dictionary with key/value attributes to use in the template
  """

  # def mailer(), do: Application.get_env(:rivet_email, :mailer)

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @user_model Keyword.get(opts, :user_model, Rivet.Ident.User)
      @email_model Keyword.get(opts, :email_model, Rivet.Ident.Email)
      @app Keyword.get(opts, :otp_app)
      @backend Keyword.get(opts, :backend)
      require Logger

      @type email_model() :: @email_model.t()
      @type user_model() :: @user_model.t()
      @type user_id() :: String.t()
      @type email_recipient() :: email_model() | user_model() | user_id()

      def send(recips, template, opts \\ []) do
        with {:ok, emails} <- get_emails(recips), {:ok, attrs} <- get_cfg(opts) do
          send_all(emails, template, attrs)
        end
      end

      defp send_all([recip | rest], template, opts) do
        with {:ok, _} <- deliver(recip, template, opts) do
          send_all(rest, template, opts)
        end
      end

      defp send_all([], _, _), do: :ok

      ##########################################################################
      defp get_cfg(opts) do
        {:ok,
         Application.get_env(@app, :email)
         |> Keyword.merge(opts)
         |> Map.new()
         |> case do
           # if email_from is a list, it should be of tuples (but json doesn't allow that)
           %{email_from: [name, email]} = cfg ->
             Map.put(cfg, :email_from, {name, email})

           other ->
             other
         end}
      end

      ##########################################################################
      @spec deliver(recipient :: any(), template :: atom(), opts :: map()) ::
              {:ok, Bamboo.Email.t()} | {:error, term()}
      def deliver(%@email_model{} = recipient, template, opts) do
        case template.generate(recipient, opts) do
          {:ok, subject, body} ->
            Bamboo.Email.new_email(to: recipient.address, from: opts.email_from)
            |> Bamboo.Email.subject(subject)
            |> Bamboo.Email.html_body("<html><body>#{body}</body></html>")
            |> Bamboo.Email.text_body(Rivet.Email.Template.text2html(body))
            |> send_email()

          other ->
            {:error, :invalid_template_result}
        end
      end

      ##########################################################################
      def send_email(%Bamboo.Email{to: addr, subject: subj} = email) do
        if Application.fetch_env!(:rivet_email, :enabled) do
          if String.contains?("@example.com", addr) do
            Logger.warn("Not delivering email to example email #{addr}")
            log_email(email)
            {:ok, email}
          else
            @backend.deliver_later(email)
          end
        else
          Logger.warn("Email disabled, not sending message to #{addr}", subject: subj)
          log_email(email)
          {:ok, email}
        end
      end

      ##########################################################################
      def log_email(%Bamboo.Email{} = email) do
        Logger.warning("""
        Subject: #{email.subject}
        --- html
        #{email.html_body}
        --- text
        #{email.text_body}
        """)
      end

      ##########################################################################
      # future: opts can include verfied: true (or some way to only send to verified addresses)
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
