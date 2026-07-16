defmodule Rivet.Email do
  require Logger

  ##############################################################################
  def mailer(), do: Application.get_env(:rivet_email, :mailer)

  @type state :: %{
          this: atom(),
          from: list(String.t() | atom()),
          user: module(),
          email: module(),
          backend: module(),
          config: module()
        }

  # map is the Email or User struct and is validated later
  @type recip :: map()
  @type recips :: recip() | list(recip())
  @type template :: module()
  @type sendto_result :: {:error, String.t()} | {:error, String.t(), list()} | {:ok, results :: list(String.t())}
  @type assigns :: keyword() | map()

  @spec sendto_(
          state(),
          recips(),
          template(),
          assigns(),
          config :: list(String.t())
        ) :: sendto_result()

  def sendto_(state, recips, template, assigns, configs)
      when is_list(configs) and is_atom(template) do
    with {:ok, emails} <- get_emails_(state, recips, template, []),
         {:ok, assigns} <- generate_assigns_(state, assigns, configs) do
      send_all_(state, emails, template, assigns, [])
    end
  end

  ##########################################################################
  defp send_all_(state, [recip | rest], template, assigns, out) when is_map(assigns) do
    case deliver_(state, recip, template, assigns) do
      {:ok, result} -> send_all_(state, rest, template, assigns, [result | out])
      {:error, error} -> {:error, error, out}
    end
  end

  defp send_all_(_, [], _, _, out), do: {:ok, out}

  ##########################################################################
  defp reduce_load_config_(state, name, {:ok, cfgs}) do
    case state.config.load_site(name) do
      {:ok, config} -> {:cont, {:ok, Map.merge(cfgs, config)}}
      {:error, e} -> {:halt, {:error, "Email Configuration not found: #{inspect(e)}"}}
    end
  end

  ##########################################################################
  def generate_assigns_(state, %{} = assigns, configs) do
    with {:ok, cfgs} <-
           Enum.reduce_while(configs, {:ok, %{}}, &reduce_load_config_(state, &1, &2)) do
      assigns = Map.merge(cfgs, assigns)

      case get_in(assigns, assigns[:from_key] || state.from) do
        nil ->
          {:error,
           "Sender email address is missing from assigns (@#{Enum.join(state.from, ".")})"}

        [name, email] ->
          {:ok, put_in(assigns, state.from, {name, email})}

        from ->
          {:ok, put_in(assigns, state.from, from)}
      end
    end
  end

  def generate_assigns_(state, assigns, configs) when is_list(assigns),
    do: generate_assigns_(state, Map.new(assigns), configs)

  ##########################################################################
  defp eex_lineno(trace) do
    Enum.reduce_while(trace, [], fn
      {:elixir_eval, :__FILE__, _, [file: ~c"nofile", line: line]}, stack ->
        {:halt, {:ok, "Line #{line}: ", stack}}

      line, stack ->
        {:cont, [line | stack]}
    end)
    |> case do
      {:ok, l, s} ->
        {l, s}

      x when is_list(x) ->
        IO.inspect(trace)
        Logger.warning("Could not find eval line in stack trace")
        {"", []}
    end
  end

  ##########################################################################
  @spec deliver_(map(), recipient :: any(), template :: atom(), assigns :: map()) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_(state, recipient, template, assigns) do
    # the only magic value
    assigns = Map.put(assigns, :recipient, recipient)

    case template.generate(recipient, assigns) do
      {:ok, subject, body} ->
        Swoosh.Email.new(to: recipient.address, from: get_in(assigns, state.from))
        |> Swoosh.Email.subject(subject)
        |> Swoosh.Email.html_body("<html><body>#{body}</body></html>")
        |> Swoosh.Email.text_body(Rivet.Email.Template.html2text(body))
        |> send_email_(state)

      {:error, :not_found} ->
        Logger.error("Cannot send email; template missing!", template: template)
        {:error, "template missing"}

      {:error, {%KeyError{} = e, trace}} ->
        {line, trace} = eex_lineno(trace)
        {:error, {:eval, "#{line}assigns key missing: #{e.key} #{e.message}", trace}}

      {:error, {%Protocol.UndefinedError{} = e, trace}} ->
        {line, trace} = eex_lineno(trace)
        {:error, {:eval, "#{line}Protocol error: #{inspect(e)}", trace}}

      {:error, {%UndefinedFunctionError{} = e, trace}} ->
        {line, trace} = eex_lineno(trace)

        {:error,
         {:eval, "#{line}undefined function: #{e.function}/#{e.arity} #{e.message}", trace}}

      # note for future reference: the EEX engine doesn't currently allow
      # for handling @assigns missing at the top level. There is a note to
      # have this be a future v2.0 thing, but until then we only get logged
      # messages, alas.

      other ->
        Logger.debug("error processing template", error: other)
        {:error, {:unknown, other}}
    end
  end

  ##########################################################################

  def send_email_(%Swoosh.Email{} = email, %{backend: backend}) do
    # runtime config not compile time, as the same container may be used in
    # tst/qa and prod, with diff enabled settings
    if Application.get_env(:rivet_email, :enabled) do
      Logger.debug("sending email", to: email.to, from: email.from, subject: email.subject)
      backend.deliver(email)
    else
      Logger.warning("Email disabled, not sending message",
        from: email.from,
        to: email.to,
        subject: email.subject
      )

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
  # email_recipient() | list(email_recipient)) ::
  @spec get_emails_(state(), recips(), template(), recips()) ::
          {:ok, recips()} | {:error, String.t(), term()}

  def get_emails_(state, [recip | recips], t, out) do
    case state.this.get_email(recip) do
      {:ok, email} ->
        get_emails_(state, recips, t, [email | out])

      {:error, %{reason: :no_email, user: user}} ->
        {:error, "Unable to load email for user, cannot send email", user: user.id}

      err ->
        {:error, "Unable to find email", err}
    end
  end

  def get_emails_(_, [], _, [_ | _] = out), do: {:ok, out}

  def get_emails_(_, [], t, []), do: no_recips(t)

  # if they send in a single struct with the proper type, turn it into a list
  def get_emails_(%{email: email} = state, %email{} = recip, t, out),
    do: get_emails_(state, [recip], t, out)

  def get_emails_(%{user: user} = state, %user{} = recip, t, out),
    do: get_emails_(state, [recip], t, out)

  def get_emails_(_, r, t, _) do
    Logger.error("bad recipient", bad_recip: r)
    no_recips(t)
  end

  ##############
  defp no_recips(template) do
    msg = "Cannot send email without recipient!"
    Logger.error(msg, template: template)
    {:error, msg}
  end

  ##############################################################################
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @type user_id() :: String.t()
      @type email_model() :: @email_model.t()
      @type user_model() :: @user_model.t()
      @type email_recipient() :: email_model() | user_model()

      @from_key Keyword.get(opts, :from_key, [:email_from])
      @user_model Keyword.get(opts, :user_model, Rivet.Ident.User)
      @email_model Keyword.get(opts, :email_model, Rivet.Ident.Email)
      @backend Keyword.get(opts, :backend)
      @configurator Keyword.get(opts, :configurator)
      require Logger

      @state %{
        this: __MODULE__,
        from: @from_key,
        user: @user_model,
        email: @email_model,
        backend: @backend,
        config: @configurator
      }

      # TODO: figure out the right path to send in alt "site" configuration at runtime and
      # have it cascade properly across all things
      ##########################################################################
      @spec get_email(email_recipient()) :: {:ok, email_model()} | {:error, reason :: any()}
      def get_email(%@email_model{} = email) do
        with {:ok, %@email_model{} = email} <- @email_model.preload(email, [:user]) do
          {:ok, email}
        end
      end

      # TODO: verified should be a settable option
      def get_email(%@user_model{} = user) do
        with {:ok, %@user_model{emails: emails}} <- @user_model.preload(user, [:emails]) do
          case Enum.find(emails, fn e -> e.verified end) do
            %@email_model{} = email ->
              {:ok, %@email_model{email | user: user}}

            _ ->
              case List.first(emails) do
                %@email_model{} = email -> {:ok, %@email_model{email | user: user}}
                _ -> {:error, :no_email}
              end
          end
        end
      end

      # def get_email(user_id) when is_binary(user_id) do
      #   with {:ok, user} <- @user_model.one(user_id) do
      #     get_email(user)
      #   end
      # end

      ##########################################################################
      # configs=[""] is "default site" configuration
      def sendto(recips, template, assigns \\ [], configs \\ [""]) when is_atom(template),
        do: Rivet.Email.sendto_(@state, recips, template, assigns, configs)
    end
  end
end
