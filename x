diff --git a/.gitignore b/.gitignore
index 48dd547..e8f0c03 100644
--- a/.gitignore
+++ b/.gitignore
@@ -23,5 +23,5 @@ erl_crash.dump
 
 /**/.DS_Store
 
-src/priv/plts/*.plt
-src/priv/plts/*.plt.hash
+priv/plts/*.plt
+priv/plts/*.plt.hash
diff --git a/config/config.exs b/config/config.exs
index f1183fc..8330906 100644
--- a/config/config.exs
+++ b/config/config.exs
@@ -1,31 +1,32 @@
 import Config
 
-config :logger, level: :info
+# Print only warnings and errors during test
+config :logger, level: :warning
 
-config :rivet,
-  repo: Rivet.Email.Repo,
-  table_prefix: "",
-  test: true
+config :rivet, app: :rivet_email, repo: Rivet.Email.Repo
 
 # This is set in your app, to allow other things to know what you've named your
 # mail sender (the Rivet.Email module)
 config :rivet_email,
   ecto_repos: [Rivet.Email.Repo],
-  enabled: false,
+  enabled: true,
   mailer: Rivet.Email.Example.Mailer,
   configurator: Rivet.Email.Example.Configurator,
   # a special row in the templates table with JSON/config data for all templates
   site_configs: "--config:site"
 
 # See Swoosh Mailer docs for more information on this configuration
-config :rivet_email, Rivet.Email.Example.Mailer.Backend,
-  adapter: Swoosh.Adapters.SMTP,
-  relay: "mail.example.com",
-  hostname: "example.com",
-  port: 25,
-  tls: :if_available,
-  retries: 2,
-  no_mx_lookups: true,
-  auth: :if_available
+config :rivet_email, Rivet.Email.Example.Mailer.Backend, adapter: Rivet.Email.Swoosh.Adapter.Test
+# adapter: Swoosh.Adapters.SMTP
 
-import_config "#{config_env()}.exs"
+config :ex_unit, capture_log: true
+
+config :rivet_email, Rivet.Email.Repo,
+  migration_repo: Rivet.Email.Repo,
+  pool_size: 20,
+  username: "postgres",
+  password: "",
+  database: "rivet_email_test",
+  hostname: "localhost",
+  log: false,
+  pool: Ecto.Adapters.SQL.Sandbox
diff --git a/config/dev.exs b/config/dev.exs
deleted file mode 100644
index becde76..0000000
--- a/config/dev.exs
+++ /dev/null
@@ -1 +0,0 @@
-import Config
diff --git a/config/prod.exs b/config/prod.exs
deleted file mode 100644
index becde76..0000000
--- a/config/prod.exs
+++ /dev/null
@@ -1 +0,0 @@
-import Config
diff --git a/config/test.exs b/config/test.exs
deleted file mode 100644
index 5e9a307..0000000
--- a/config/test.exs
+++ /dev/null
@@ -1,10 +0,0 @@
-import Config
-
-# Print only warnings and errors during test
-config :logger, level: :warning
-
-config :ex_unit, capture_log: true
-
-config :rivet_email,
-  enabled: false,
-  mailer: Rivet.Email.Example.Mailer
diff --git a/future.md b/future.md
new file mode 100644
index 0000000..3aaad0b
--- /dev/null
+++ b/future.md
@@ -0,0 +1,5 @@
+# EMAIL_CONFIGS table
+
+* revise and add table email_configs and stop doing //CONFIG/site things
+* on email-configs site is optional per config
+* refactor all that site & config stuff
diff --git a/lib/email/config/index.ex b/lib/email/config/index.ex
new file mode 100644
index 0000000..e0773f9
--- /dev/null
+++ b/lib/email/config/index.ex
@@ -0,0 +1,38 @@
+defmodule Rivet.Email.Config do
+  use TypedEctoSchema
+  use Rivet.Ecto.Model
+
+  typed_schema "email_configs" do
+    field(:site, :string, default: "")
+    field(:group, :string)
+    field(:key, :string)
+    field(:value, __MODULE__.Value)
+    timestamps()
+  end
+
+  def set(group, key, value, site \\ ""),
+    do:
+      replace(%{site: site, group: group, key: key, value: value},
+        site: site,
+        group: group,
+        key: key
+      )
+
+  def load_site(site) do
+    with {:ok, list} <- all(site: site) do
+      {:ok,
+       Enum.reduce(list, %{}, fn %{group: group, key: key, value: value}, map ->
+         group = String.to_atom(group)
+         key = String.to_atom(key)
+         put_in(map, [Access.key(group, %{}), key], value)
+       end)}
+    end
+  end
+
+  use Rivet.Ecto.Collection,
+    not_found: :atom,
+    required: [:group, :key],
+    create: [:site],
+    update: [:value],
+    unique_constraints: [[:site, :group, :key]]
+end
diff --git a/lib/email/config/migrate.ex b/lib/email/config/migrate.ex
new file mode 100644
index 0000000..553b8fc
--- /dev/null
+++ b/lib/email/config/migrate.ex
@@ -0,0 +1,30 @@
+defmodule Rivet.Email.Config.Migrate do
+  import Ecto.Query
+
+  # temp
+  def migrate(repo) do
+    from(t in Rivet.Email.Template, where: like(t.name, "//CONFIG%"))
+    |> repo.all()
+    |> Enum.each(fn t ->
+      site = t.name |> Atom.to_string() |> String.slice(9..-1//1)
+      site = if site == "site", do: "", else: site
+
+      for {group, vals} <- Jason.decode!(t.data) do
+        for {key, value} <- vals do
+          IO.puts("#{site}:#{group}.#{key}=#{inspect(value)}")
+          {:ok, _} = Rivet.Email.Config.set(group, key, value, site)
+        end
+      end
+    end)
+  end
+
+  def test_data() do
+    {:ok, _} =
+      Rivet.Email.Template.create(%{
+        id: "a228dffd-4ce7-46c6-ab40-480f44d76279",
+        name: "//CONFIG/site",
+        data:
+          "{\"addrs\": {\n  \"from\": [ \"Cato Digital Team\", \"noreply@cato.digital\" ],\n  \"support\": [\"Cato Support\", \"support@cato.digital\" ],\n  \"sales\": [\"Cato Support\", \"sales@cato.digital\" ],\n  \"errors\": [\"Cato Dev Errors\", \"dev-errors-ZGV2LWV@cato.digital\" ]\n},\n\"site\":{\n  \"name\": \"Cato Digital\",\n  \"link_back\": \"https://api.cato.digital\",\n  \"link_front\": \"https://console.cato.digital\",\n  \"link_setup\": \"https://cato.digital/kb/1010-server-setup/\",\n  \"html_support\": \"<a href=\\\"https://cato.digital/support/\\\">Cato Support Team</a>\",\n  \"footer\": \"<p>Sincerely, Cato Digital<p>\"\n}}"
+      })
+  end
+end
diff --git a/lib/email/config/value.ex b/lib/email/config/value.ex
new file mode 100644
index 0000000..dee89f4
--- /dev/null
+++ b/lib/email/config/value.ex
@@ -0,0 +1,27 @@
+defmodule Rivet.Email.Config.Value do
+  # true json
+  @behaviour Ecto.Type
+
+  @type t :: binary() | list(binary())
+
+  @impl true
+  def type, do: :map
+
+  defp config_value(v) when is_binary(v), do: {:ok, v}
+
+  # email name/addr tuple
+  defp config_value([n, e]) when is_binary(n) and is_binary(e), do: {:ok, [n, e]}
+
+  defp config_value(_), do: :error
+
+  @impl true
+  def cast(v), do: config_value(v)
+  @impl true
+  def load(v), do: config_value(v)
+  @impl true
+  def dump(v), do: config_value(v)
+  @impl true
+  def equal?(a, b), do: a == b
+  @impl true
+  def embed_as(_), do: :dump
+end
diff --git a/lib/email/configurator.ex b/lib/email/configurator.ex
index 6c60ac0..6fda549 100644
--- a/lib/email/configurator.ex
+++ b/lib/email/configurator.ex
@@ -3,38 +3,77 @@ defmodule Rivet.Email.Configurator do
     quote location: :keep, bind_quoted: [opts: opts] do
       use Rivet.Utils.LazyCache
 
-      @persist_for 600_000
-
-      def get({name, nil}), do: get_(name)
+      def conf(grp, key, site \\ "") do
+        get_through({site, grp, key}, fn _ ->
+          with {:ok, %{value: value}} <- Rivet.Email.Config.one(site: site, group: grp, key: key),
+            do: {:ok, value}
+        end)
+      end
 
-      def get({name, site}) do
-        case get_("#{name}/#{site}") do
-          {:ok, _} = pass -> pass
-          _ -> get_(name)
+      def conf!(grp, key, site \\ "") do
+        case conf(grp, key, site) do
+          {:ok, value} -> value
+          {:error, :not_found} -> raise "email config not found: #{site}.#{grp}.#{key}"
         end
       end
 
-      def get(name), do: get_(name)
-
-      defp get_(name) do
-        case lookup(name) do
-          [{_, target, _}] ->
-            {:ok, target}
-
-          _ ->
-            case Rivet.Email.Template.one(name: "//CONFIG/#{name}") do
-              {:ok, c} ->
-                with {:ok, data} <- Jason.decode(c.data) do
-                  data = Transmogrify.transmogrify(data)
-                  insert(name, data, @persist_for)
-                  {:ok, data}
-                end
-
-              _ ->
-                {:error, :not_found}
-            end
-        end
+      def load_site(site) do
+        get_through(site, fn _ ->
+          Rivet.Email.Config.load_site(site)
+        end)
       end
     end
   end
+
+  # @persist_for 600_000
+  #
+  # ##############################################################################
+  # # base config for all sites
+  # def get_key_(parent, "site", key), do: get_config_key_(parent, "site", key)
+  #
+  # # named site, not base
+  # def get_key_(parent, <<site::binary>>, key) do
+  #   with {:error, _} <- get_config_key_(parent, site, key),
+  #        do: get_config_key_(parent, "site", key)
+  # end
+  #
+  # # similarly, but for the full config
+  # def get_config_(parent, "site"), do: get_config__(parent, "site")
+  #
+  # def get_config_(parent, <<name::binary>>) do
+  #   with {:error, _} <- get_config__(parent, name), do: get_config__(parent, "site")
+  # end
+  #
+  # ##########################################################################
+  # def get_config_key_(parent, cfgname, key) when is_list(key) do
+  #   with {:ok, cfg} <- get_config__(parent, cfgname),
+  #        do: get_in_(cfg, key)
+  # end
+  #
+  # def get_in_(cfg, key) when is_map(cfg) do
+  #   case get_in(cfg, key) do
+  #     nil -> {:error, :not_found}
+  #     value -> {:ok, value}
+  #   end
+  # end
+  #
+  # def get_config__(parent, cfgname) do
+  #   case parent.lookup(cfgname) do
+  #     [{_, target, _}] ->
+  #       {:ok, target}
+  #
+  #     _ ->
+  #       case Rivet.Email.Template.one(name: "//CONFIG/#{cfgname}") do
+  #         {:ok, c} ->
+  #           with {:ok, data} <- Jason.decode(c.data) do
+  #             data = Transmogrify.transmogrify(data)
+  #             parent.insert(cfgname, data, @persist_for)
+  #             {:ok, data}
+  #           end
+  #
+  #         _ ->
+  #           {:error, "no email template for: #{cfgname}"}
+  #       end
+  #   end
+  # end
 end
diff --git a/lib/email/index.ex b/lib/email/index.ex
index d80b7d1..a09ed19 100644
--- a/lib/email/index.ex
+++ b/lib/email/index.ex
@@ -1,189 +1,243 @@
 defmodule Rivet.Email do
+  require Logger
+
+  ##############################################################################
   def mailer(), do: Application.get_env(:rivet_email, :mailer)
 
-  defmacro __using__(opts) do
-    quote location: :keep, bind_quoted: [opts: opts] do
-      @from_key Keyword.get(opts, :from_key, [:email_from])
-      @user_model Keyword.get(opts, :user_model, Rivet.Ident.User)
-      @email_model Keyword.get(opts, :email_model, Rivet.Ident.Email)
-      @backend Keyword.get(opts, :backend)
-      @configurator Keyword.get(opts, :configurator)
-      require Logger
+  @type state :: %{
+          this: atom(),
+          from: list(String.t() | atom()),
+          user: module(),
+          email: module(),
+          backend: module(),
+          config: module()
+        }
+
+  # map is the Email or User struct and is validated later
+  @type recip :: map()
+  @type recips :: recip() | list(recip())
+  @type template :: module()
+  @type sendto_result :: {:error, String.t()} | {:error, String.t(), list()} | {:ok, results :: list(String.t())}
+
+  @spec sendto_(
+          state(),
+          recips(),
+          template(),
+          assigns :: keyword() | map(),
+          config :: list(String.t())
+        ) :: sendto_result()
+
+  def sendto_(state, recips, template, assigns, configs)
+      when is_list(configs) and is_atom(template) do
+    with {:ok, emails} <- get_emails_(state, recips, template, []),
+         {:ok, assigns} <- generate_assigns_(state, assigns, configs) do
+      send_all_(state, emails, template, assigns, [])
+    end
+  end
 
-      @type email_model() :: @email_model.t()
-      @type user_model() :: @user_model.t()
-      @type user_id() :: String.t()
-      @type email_recipient() :: email_model() | user_model() | user_id()
+  ##########################################################################
+  defp send_all_(state, [recip | rest], template, assigns, out) when is_map(assigns) do
+    case deliver_(state, recip, template, assigns) do
+      {:ok, result} -> send_all_(state, rest, template, assigns, [result | out])
+      {:error, error} -> {:error, error, [out] |> Enum.reverse()}
+    end
+  end
 
-      def sendto(recips, template, assigns \\ [], configs \\ [])
+  defp send_all_(_, [], _, _, out), do: {:ok, Enum.reverse(out)}
 
-      def sendto([], template, assigns, configs),
-        do: Logger.error("Cannot send email to no recipients!", template: template)
+  ##########################################################################
+  defp reduce_load_config_(state, name, {:ok, cfgs}) do
+    case state.config.load_site(name) do
+      {:ok, config} -> {:cont, {:ok, Map.merge(cfgs, config)}}
+      {:error, e} -> {:halt, {:error, "Email Configuration not found: #{inspect(e)}"}}
+    end
+  end
 
-      def sendto(recips, template, assigns, configs) do
-        with {:ok, emails} <- get_emails(recips),
-             {:ok, assigns} <- generate_assigns(assigns, configs) do
-          send_all(emails, template, assigns, [])
-        end
-      end
+  ##########################################################################
+  def generate_assigns_(state, %{} = assigns, configs) do
+    with {:ok, cfgs} <-
+           Enum.reduce_while(configs, {:ok, %{}}, &reduce_load_config_(state, &1, &2)) do
+      assigns = Map.merge(cfgs, assigns)
 
-      ##########################################################################
-      defp send_all([recip | rest], template, assigns, out) when is_map(assigns) do
-        case deliver(recip, template, assigns) do
-          {:ok, result} ->
-            send_all(rest, template, assigns, [result | out])
-
-          {:error, error} ->
-            {:error, error, [out] |> Enum.reverse()}
-            # other -> {:error, other, [out] |> Enum.reverse()}
-        end
+      case get_in(assigns, assigns[:from_key] || state.from) do
+        nil ->
+          {:error,
+           "Sender email address is missing from assigns (@#{Enum.join(state.from, ".")})"}
+
+        [name, email] ->
+          {:ok, put_in(assigns, state.from, {name, email})}
+
+        from ->
+          {:ok, put_in(assigns, state.from, from)}
       end
+    end
+  end
 
-      defp send_all([], _, _, out), do: {:ok, Enum.reverse(out)}
+  def generate_assigns_(state, assigns, configs) when is_list(assigns),
+    do: generate_assigns_(state, Map.new(assigns), configs)
+
+  ##########################################################################
+  defp eex_lineno(trace) do
+    Enum.reduce_while(trace, [], fn
+      {:elixir_eval, :__FILE__, _, [file: ~c"nofile", line: line]}, stack ->
+        {:halt, {:ok, "Line #{line}: ", stack}}
+
+      line, stack ->
+        {:cont, [line | stack]}
+    end)
+    |> case do
+      {:ok, l, s} ->
+        {l, s}
+
+      x when is_list(x) ->
+        IO.inspect(trace)
+        Logger.warning("Could not find eval line in stack trace")
+        {"", []}
+    end
+  end
 
-      ##########################################################################
-      # future: for scale of thousands/second, add a read-through cache with Rivet lazy cache
-      defp get_config(name), do: @configurator.get(name)
+  ##########################################################################
+  @spec deliver_(map(), recipient :: any(), template :: atom(), assigns :: map()) ::
+          {:ok, Swoosh.Email.t()} | {:error, term()}
+  def deliver_(state, recipient, template, assigns) do
+    # the only magic value
+    assigns = Map.put(assigns, :recipient, recipient)
+
+    case template.generate(recipient, assigns) do
+      {:ok, subject, body} ->
+        Swoosh.Email.new(to: recipient.address, from: get_in(assigns, state.from))
+        |> Swoosh.Email.subject(subject)
+        |> Swoosh.Email.html_body("<html><body>#{body}</body></html>")
+        |> Swoosh.Email.text_body(Rivet.Email.Template.html2text(body))
+        |> send_email_(state)
+
+      {:error, :not_found} ->
+        Logger.error("Cannot send email; template missing!", template: template)
+        {:error, "template missing"}
+
+      {:error, {%KeyError{} = e, trace}} ->
+        {line, trace} = eex_lineno(trace)
+        {:error, {:eval, "#{line}assigns key missing: #{e.key} #{e.message}", trace}}
+
+      {:error, {%Protocol.UndefinedError{} = e, trace}} ->
+        {line, trace} = eex_lineno(trace)
+        {:error, {:eval, "#{line}Protocol error: #{inspect(e)}", trace}}
+
+      {:error, {%UndefinedFunctionError{} = e, trace}} ->
+        {line, trace} = eex_lineno(trace)
+
+        {:error,
+         {:eval, "#{line}undefined function: #{e.function}/#{e.arity} #{e.message}", trace}}
+
+      # note for future reference: the EEX engine doesn't currently allow
+      # for handling @assigns missing at the top level. There is a note to
+      # have this be a future v2.0 thing, but until then we only get logged
+      # messages, alas.
+
+      other ->
+        Logger.debug("error processing template", error: other)
+        {:error, {:unknown, other}}
+    end
+  end
 
-      defp reduce_load_config(name, {:ok, cfgs}) do
-        case get_config(name) do
-          {:ok, config} -> {:cont, {:ok, Map.merge(cfgs, config)}}
-          {:error, :not_found} -> {:halt, {:error, "Email Configuration not found: #{name}"}}
-        end
-      end
+  ##########################################################################
 
-      ##########################################################################
-      def generate_assigns(assigns, configs) do
-        with {:ok, cfgs} <- Enum.reduce_while(configs, {:ok, %{}}, &reduce_load_config/2) do
-          assigns = Map.merge(cfgs, Map.new(assigns))
+  if Application.compile_env(:rivet_email, :enabled) do
+    def send_email_(%Swoosh.Email{} = email, %{backend: backend}) do
+      Logger.debug("sending email", to: email.to, from: email.from, subject: email.subject)
+      backend.deliver(email)
+    end
+  else
+    def send_email_(%Swoosh.Email{} = email, _) do
+      Logger.warning("Email disabled, not sending message",
+        from: email.from,
+        to: email.to,
+        subject: email.subject
+      )
+
+      log_email(email)
+      {:ok, "email disabled"}
+    end
+  end
+
+  ##########################################################################
+  def log_email(%Swoosh.Email{} = email) do
+    Logger.warning("""
+    Subject: #{email.subject}
+    --- html
+    #{email.html_body}
+    --- text
+    #{email.text_body}
+    """)
+  end
 
-          case get_in(assigns, @from_key) do
-            nil ->
-              {:error,
-               "Sender email address is missing from assigns (@#{Enum.join(@from_key, ".")})"}
+  ##########################################################################
+  # email_recipient() | list(email_recipient)) ::
+  @spec get_emails_(state(), recips(), template(), recips()) ::
+          {:ok, recips()} | {:error, String.t(), term()}
 
-            [name, email] ->
-              {:ok, put_in(assigns, @from_key, {name, email})}
+  def get_emails_(state, [recip | recips], t, out) do
+    case state.this.get_email(recip) do
+      {:ok, email} ->
+        get_emails_(state, recips, t, [email | out])
 
-            from ->
-              {:ok, put_in(assigns, @from_key, from)}
-          end
-        end
-      end
+      {:error, %{reason: :no_email, user: user}} ->
+        {:error, "Unable to load email for user, cannot send email", user: user.id}
 
-      ##########################################################################
-      defp eex_lineno(trace) do
-        Enum.reduce_while(trace, [], fn
-          {:elixir_eval, :__FILE__, _, [file: ~c"nofile", line: line]}, stack ->
-            {:halt, {:ok, "Line #{line}: ", stack}}
-
-          line, stack ->
-            {:cont, [line | stack]}
-        end)
-        |> case do
-          {:ok, l, s} ->
-            {l, s}
-
-          x when is_list(x) ->
-            IO.inspect(trace)
-            Logger.warning("Could not find eval line in stack trace")
-            {"", []}
-        end
-      end
+      err ->
+        {:error, "Unable to find email", err}
+    end
+  end
 
-      ##########################################################################
-      @spec deliver(recipient :: any(), template :: atom(), assigns :: map()) ::
-              {:ok, Swoosh.Email.t()} | {:error, term()}
-      def deliver(%@email_model{} = recipient, template, assigns) do
-        # the only magic value
-        assigns = Map.put(assigns, :recipient, recipient)
-
-        case template.generate(recipient, assigns) do
-          {:ok, subject, body} ->
-            Swoosh.Email.new(to: recipient.address, from: get_in(assigns, @from_key))
-            |> Swoosh.Email.subject(subject)
-            |> Swoosh.Email.html_body("<html><body>#{body}</body></html>")
-            |> Swoosh.Email.text_body(Rivet.Email.Template.html2text(body))
-            |> send_email()
-
-          {:error, :not_found} ->
-            Logger.error("Cannot send email; template missing!", template: template)
-            {:error, "template missing"}
-
-          {:error, {%KeyError{} = e, trace}} ->
-            {line, trace} = eex_lineno(trace)
-            {:error, {:eval, "#{line}assigns key missing: #{e.key} #{e.message}", trace}}
-
-          {:error, {%Protocol.UndefinedError{} = e, trace}} ->
-            {line, trace} = eex_lineno(trace)
-            {:error, {:eval, "#{line}Protocol error: #{inspect(e)}", trace}}
-
-          {:error, {%UndefinedFunctionError{} = e, trace}} ->
-            {line, trace} = eex_lineno(trace)
-
-            {:error,
-             {:eval, "#{line}undefined function: #{e.function}/#{e.arity} #{e.message}", trace}}
-
-          # note for future reference: the EEX engine doesn't currently allow
-          # for handling @assigns missing at the top level. There is a note to
-          # have this be a future v2.0 thing, but until then we only get logged
-          # messages, alas.
-
-          other ->
-            Logger.debug("error processing template", error: other)
-            {:error, {:unknown, other}}
-        end
-      end
+  def get_emails_(_, [], _, [_ | _] = out), do: {:ok, out}
 
-      ##########################################################################
-      def send_email(%Swoosh.Email{to: [{_, eaddr} = addr], subject: subj} = email) do
-        if Application.get_env(:rivet_email, :enabled) do
-          if String.ends_with?("@example.com", eaddr) do
-            {:error, :example_email}
-          else
-            Logger.debug("sending email", to: eaddr, from: email.from, subject: subj)
-            @backend.deliver(email)
-          end
-        else
-          Logger.warning("Email disabled, not sending message to #{inspect(addr)}", subject: subj)
-          log_email(email)
-          {:ok, "email disabled"}
-        end
-      end
+  def get_emails_(_, [], t, []), do: no_recips(t)
 
-      ##########################################################################
-      def log_email(%Swoosh.Email{} = email) do
-        Logger.warning("""
-        Subject: #{email.subject}
-        --- html
-        #{email.html_body}
-        --- text
-        #{email.text_body}
-        """)
-      end
+  # if they send in a single struct with the proper type, turn it into a list
+  def get_emails_(%{email: email} = state, %email{} = recip, t, out),
+    do: get_emails_(state, [recip], t, out)
 
-      ##########################################################################
-      # future: assigns can include verfied: true (or some way to only send to verified addresses)
-      @spec get_emails(email_recipient() | list(email_recipient)) ::
-              {:ok, list(email_model())} | {:error, String.t(), term()}
+  def get_emails_(%{user: user} = state, %user{} = recip, t, out),
+    do: get_emails_(state, [recip], t, out)
 
-      def get_emails(recip, out \\ [])
+  def get_emails_(r, _, t, _) do
+    Logger.error("bad recipient", bad_recip: r)
+    no_recips(t)
+  end
 
-      def get_emails([recip | recips], out) do
-        with {:ok, email} <- get_email(recip) do
-          get_emails(recips, [email | out])
-        else
-          {:error, %{reason: :no_email, user: user}} ->
-            {:error, "Unable to load email for user, cannot send email", user: user.id}
+  ##############
+  defp no_recips(template) do
+    msg = "Cannot send email without recipient!"
+    Logger.error(msg, template: template)
+    {:error, msg}
+  end
 
-          err ->
-            {:error, "Unable to find email", err}
-        end
-      end
+  ##############################################################################
+  defmacro __using__(opts) do
+    quote location: :keep, bind_quoted: [opts: opts] do
+      @type user_id() :: String.t()
+      @type email_model() :: @email_model.t()
+      @type user_model() :: @user_model.t()
+      @type email_recipient() :: email_model() | user_model()
 
-      def get_emails([], out), do: {:ok, out}
-      def get_emails(recip, out), do: get_emails([recip], out)
+      @from_key Keyword.get(opts, :from_key, [:email_from])
+      @user_model Keyword.get(opts, :user_model, Rivet.Ident.User)
+      @email_model Keyword.get(opts, :email_model, Rivet.Ident.Email)
+      @backend Keyword.get(opts, :backend)
+      @configurator Keyword.get(opts, :configurator)
+      require Logger
 
+      @state %{
+        this: __MODULE__,
+        from: @from_key,
+        user: @user_model,
+        email: @email_model,
+        backend: @backend,
+        config: @configurator
+      }
+
+      # TODO: figure out the right path to send in alt "site" configuration at runtime and
+      # have it cascade properly across all things
       ##########################################################################
       @spec get_email(email_recipient()) :: {:ok, email_model()} | {:error, reason :: any()}
       def get_email(%@email_model{} = email) do
@@ -200,21 +254,24 @@ defmodule Rivet.Email do
               {:ok, %@email_model{email | user: user}}
 
             _ ->
-              with %@email_model{} = email <- List.first(emails) do
-                {:ok, %@email_model{email | user: user}}
-              else
-                _ ->
-                  {:error, :no_email}
+              case List.first(emails) do
+                %@email_model{} = email -> {:ok, %@email_model{email | user: user}}
+                _ -> {:error, :no_email}
               end
           end
         end
       end
 
-      def get_email(user_id) when is_binary(user_id) do
-        with {:ok, user} <- @user_model.one(user_id) do
-          get_email(user)
-        end
-      end
+      # def get_email(user_id) when is_binary(user_id) do
+      #   with {:ok, user} <- @user_model.one(user_id) do
+      #     get_email(user)
+      #   end
+      # end
+
+      ##########################################################################
+      # configs=[""] is "default site" configuration
+      def sendto(recips, template, assigns \\ [], configs \\ [""]) when is_atom(template),
+        do: Rivet.Email.sendto_(@state, recips, template, assigns, configs)
     end
   end
 end
diff --git a/lib/email/template/index.ex b/lib/email/template/index.ex
index 100ae74..f75f755 100644
--- a/lib/email/template/index.ex
+++ b/lib/email/template/index.ex
@@ -1,14 +1,15 @@
 defmodule Rivet.Email.Template do
   @callback generate(recipient :: map(), attributes :: map()) ::
               {:ok, subject :: String.t(), html_body :: String.t()}
-  @callback sendto(recipients :: any(), assigns :: list()) :: :ok
+  @callback template_send(recipients :: any(), assigns :: list()) :: Rivet.Email.sendto_result()
+  @callback template_send(recipients :: any(), assigns :: list(), config :: list()) :: Rivet.Email.sendto_result()
 
   use TypedEctoSchema
   use Rivet.Ecto.Model
 
   typed_schema "email_templates" do
     field(:name, Rivet.Utils.Ecto.Atom)
-    field(:data, :string)
+    field(:data, :string, default: "")
     timestamps()
   end
 
@@ -20,7 +21,7 @@ defmodule Rivet.Email.Template do
 
   @doc ~S"""
   iex> html2text("<b>an html doc</b><p><h1>Header</h1>")
-  "**an html doc** \n# Header"
+  "**an html doc**\n\n# Header"
   """
   @spec html2text(html :: String.t()) :: text :: String.t()
   def html2text(html), do: Html2Markdown.convert(html)
@@ -29,7 +30,7 @@ defmodule Rivet.Email.Template do
     quote location: :keep, bind_quoted: [opts: opts] do
       require Logger
       @assigns Keyword.get(opts, :assigns, false)
-      @configs Keyword.get(opts, :configs, ["site"])
+      @configs Keyword.get(opts, :configs, [""])
       @behaviour Rivet.Email.Template
       @tname Atom.to_string(__MODULE__)
 
@@ -54,10 +55,10 @@ defmodule Rivet.Email.Template do
       end
 
       @impl Rivet.Email.Template
-      def sendto(targets, assigns, configs \\ @configs),
+      def template_send(targets, assigns, configs \\ @configs),
         do: Rivet.Email.mailer().sendto(targets, __MODULE__, merge_assigns(assigns), configs)
 
-      defoverridable sendto: 2, sendto: 3
+      defoverridable template_send: 2, template_send: 3
 
       @impl Rivet.Email.Template
       def generate(email, assigns), do: load_and_eval(email, assigns)
diff --git a/lib/example/mailer/email.ex b/lib/example/mailer/email.ex
index cc9a398..62ad9f2 100644
--- a/lib/example/mailer/email.ex
+++ b/lib/example/mailer/email.ex
@@ -1,10 +1,18 @@
 defmodule Rivet.Email.Example.Mailer.Email do
-  defstruct id: "", address: "", user: %Rivet.Email.Example.Mailer.User{}, verified: true
+  alias Rivet.Email.Example.Mailer
+  defstruct id: "", address: "", user: %Mailer.User{}, verified: true
+
+  @type t :: %__MODULE__{
+          id: String.t(),
+          address: String.t(),
+          user: Mailer.User.t(),
+          verified: boolean()
+        }
 
   # coveralls-ignore-start
-  def preload(e, _), do: {:ok, %{e | user: Rivet.Email.Example.Mailer.User.mock()}}
+  def preload(e, _), do: {:ok, %{e | user: Mailer.User.mock()}}
   def one(_), do: {:ok, mock()}
-  # coveralls-ignore-end
+  # coveralls-ignore-stop
 
   def mock() do
     %__MODULE__{
diff --git a/lib/example/mailer/user.ex b/lib/example/mailer/user.ex
index d21792c..296371b 100644
--- a/lib/example/mailer/user.ex
+++ b/lib/example/mailer/user.ex
@@ -1,10 +1,12 @@
 defmodule Rivet.Email.Example.Mailer.User do
   defstruct id: "", name: "", emails: []
 
+  @type t :: %__MODULE__{id: String.t(), name: String.t(), emails: list()}
+
   # coveralls-ignore-start
   def preload(e, _), do: {:ok, e}
   def one(_), do: {:ok, mock()}
-  # coveralls-ignore-end
+  # coveralls-ignore-stop
 
   def mock() do
     %__MODULE__{
diff --git a/mix.exs b/mix.exs
index ffde9d5..08f2e40 100644
--- a/mix.exs
+++ b/mix.exs
@@ -5,9 +5,9 @@ defmodule RivetEmail.MixProject do
   def project do
     [
       app: :rivet_email,
-      version: "2.5.0",
+      version: "4.0.0",
       package: package(),
-      elixir: "~> 1.13",
+      elixir: "~> 1.18",
       elixirc_paths: elixirc_paths(Mix.env()),
       start_permanent: Mix.env() == :prod,
       test_coverage: [tool: ExCoveralls],
@@ -25,7 +25,7 @@ defmodule RivetEmail.MixProject do
       xref: [exclude: List.wrap(Application.get_env(:rivet, :repo))],
       source_url: @source_url,
       docs: [main: "Rivet.Email"],
-      aliases: [c: "compile"],
+      aliases: aliases(),
       description: description()
     ]
   end
@@ -35,11 +35,21 @@ defmodule RivetEmail.MixProject do
       env: [
         rivet: [
           app: :rivet_email,
-          base: "Rivet.Email",
+          base: Rivet.Email,
           models_dir: "email"
         ]
       ],
-      extra_applications: [:logger, :timex, {:ex_unit, :optional}]
+      extra_applications: [:logger, {:ex_unit, :optional}]
+    ]
+  end
+
+  defp aliases do
+    [
+      "ecto.migrate": ["rivet migrate"],
+      "ecto.setup": ["ecto.create", "rivet migrate"],
+      "ecto.reset": ["ecto.drop --force-drop -f", "ecto.setup"],
+      test: ["ecto.create --quiet", "rivet migrate", "test"],
+      c: ["compile"]
     ]
   end
 
@@ -50,15 +60,17 @@ defmodule RivetEmail.MixProject do
     [
       # please alphabetize
       {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
+      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
       {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
       {:ex_machina, "~> 2.7.0", only: :test, runtime: false},
       {:excoveralls, "~> 0.18", only: :test, runtime: false},
       {:faker, "~> 0.18", only: :test, runtime: false},
-      {:gen_smtp, "~> 1.2.0"},
-      {:html2markdown, "~> 0.1.5"},
+      {:gen_smtp, "~> 1.3"},
+      {:html2markdown, "~> 0.3"},
       {:jason, "~> 1.4"},
-      {:mix_test_watch, "~> 1.2", only: [:dev, :test], runtime: false},
-      {:rivet, "~> 2.5"},
+      {:mix_test_watch, "~> 1.4", only: [:dev, :test], runtime: false},
+      {:postgrex, "~> 0.21"},
+      {:rivet, "~> 2.7"},
       {:swoosh, "~> 1.19"},
       {:timex, "~> 3.7"},
       {:transmogrify, "~> 2.0.2"}
diff --git a/mix.lock b/mix.lock
index d4aadd6..2de0c64 100644
--- a/mix.lock
+++ b/mix.lock
@@ -1,59 +1,54 @@
 %{
-  "bcrypt_elixir": {:hex, :bcrypt_elixir, "3.3.1", "9f2e7e00f661a6acfae1431f1bc590e28698aaecc962c2a7b33150dfe9289c3d", [:make, :mix], [{:comeonin, "~> 5.3", [hex: :comeonin, repo: "hexpm", optional: false]}, {:elixir_make, "~> 0.6", [hex: :elixir_make, repo: "hexpm", optional: false]}], "hexpm", "9f539e9d3828fad4ffc8152dadc0d27c6d78cb2853a9a1d6518cfe8a5adb7f50"},
+  "bcrypt_elixir": {:hex, :bcrypt_elixir, "3.3.2", "d50091e3c9492d73e17fc1e1619a9b09d6a5ef99160eb4d736926fd475a16ca3", [:make, :mix], [{:comeonin, "~> 5.3", [hex: :comeonin, repo: "hexpm", optional: false]}, {:elixir_make, "~> 0.6", [hex: :elixir_make, repo: "hexpm", optional: false]}], "hexpm", "471be5151874ae7931911057d1467d908955f93554f7a6cd1b7d804cac8cef53"},
   "bunt": {:hex, :bunt, "1.0.0", "081c2c665f086849e6d57900292b3a161727ab40431219529f13c4ddcf3e7a44", [:mix], [], "hexpm", "dc5f86aa08a5f6fa6b8096f0735c4e76d54ae5c9fa2c143e5a1fc7c1cd9bb6b5"},
-  "certifi": {:hex, :certifi, "2.14.0", "ed3bef654e69cde5e6c022df8070a579a79e8ba2368a00acf3d75b82d9aceeed", [:rebar3], [], "hexpm", "ea59d87ef89da429b8e905264fdec3419f84f2215bb3d81e07a18aac919026c3"},
+  "certifi": {:hex, :certifi, "2.15.0", "0e6e882fcdaaa0a5a9f2b3db55b1394dba07e8d6d9bcad08318fb604c6839712", [:rebar3], [], "hexpm", "b147ed22ce71d72eafdad94f055165c1c182f61a2ff49df28bcc71d1d5b94a60"},
   "combine": {:hex, :combine, "0.10.0", "eff8224eeb56498a2af13011d142c5e7997a80c8f5b97c499f84c841032e429f", [:mix], [], "hexpm", "1b1dbc1790073076580d0d1d64e42eae2366583e7aecd455d1215b0d16f2451b"},
   "comeonin": {:hex, :comeonin, "5.5.1", "5113e5f3800799787de08a6e0db307133850e635d34e9fab23c70b6501669510", [:mix], [], "hexpm", "65aac8f19938145377cee73973f192c5645873dcf550a8a6b18187d17c13ccdb"},
-  "credo": {:hex, :credo, "1.7.12", "9e3c20463de4b5f3f23721527fcaf16722ec815e70ff6c60b86412c695d426c1", [:mix], [{:bunt, "~> 0.2.1 or ~> 1.0", [hex: :bunt, repo: "hexpm", optional: false]}, {:file_system, "~> 0.2 or ~> 1.0", [hex: :file_system, repo: "hexpm", optional: false]}, {:jason, "~> 1.0", [hex: :jason, repo: "hexpm", optional: false]}], "hexpm", "8493d45c656c5427d9c729235b99d498bd133421f3e0a683e5c1b561471291e5"},
-  "csv": {:hex, :csv, "3.0.5", "3c1455127e92de8845806db89554ad7d45e0212974be41dd9c38a5c881861713", [:mix], [], "hexpm", "cbbe5455c93df5f3f2943e995e28b7a8808361ba34cf3e44267d77a01eaf1609"},
-  "db_connection": {:hex, :db_connection, "2.7.0", "b99faa9291bb09892c7da373bb82cba59aefa9b36300f6145c5f201c7adf48ec", [:mix], [{:telemetry, "~> 0.4 or ~> 1.0", [hex: :telemetry, repo: "hexpm", optional: false]}], "hexpm", "dcf08f31b2701f857dfc787fbad78223d61a32204f217f15e881dd93e4bdd3ff"},
-  "decimal": {:hex, :decimal, "2.3.0", "3ad6255aa77b4a3c4f818171b12d237500e63525c2fd056699967a3e7ea20f62", [:mix], [], "hexpm", "a4d66355cb29cb47c3cf30e71329e58361cfcb37c34235ef3bf1d7bf3773aeac"},
+  "credo": {:hex, :credo, "1.7.18", "5c5596bf7aedf9c8c227f13272ac499fe8eae6237bd326f2f07dfc173786f042", [:mix], [{:bunt, "~> 0.2.1 or ~> 1.0", [hex: :bunt, repo: "hexpm", optional: false]}, {:file_system, "~> 0.2 or ~> 1.0", [hex: :file_system, repo: "hexpm", optional: false]}, {:jason, "~> 1.0", [hex: :jason, repo: "hexpm", optional: false]}], "hexpm", "a189d164685fd945809e862fe76a7420c4398fa288d76257662aecb909d6b3e5"},
+  "db_connection": {:hex, :db_connection, "2.10.1", "d5465f6bcc125c1b8981c1dbf23c193ca16f446ec0b25832dc174f74f18be510", [:mix], [{:telemetry, "~> 0.4 or ~> 1.0", [hex: :telemetry, repo: "hexpm", optional: false]}], "hexpm", "18ed94c6e627b4bf452dbd4df61b69a35a1e768525140bc1917b7a685026a6a3"},
+  "decimal": {:hex, :decimal, "3.1.0", "9ede268cff827e6f0c4fb1b34747c82630dce5d7b877dfb22ec8f0cb25855fce", [:mix], [], "hexpm", "e8b3efb3bb3a13cb5e4268ffe128569067b1972e9dee013537c71a5b073168f9"},
+  "dialyxir": {:hex, :dialyxir, "1.4.7", "dda948fcee52962e4b6c5b4b16b2d8fa7d50d8645bbae8b8685c3f9ecb7f5f4d", [:mix], [{:erlex, ">= 0.2.8", [hex: :erlex, repo: "hexpm", optional: false]}], "hexpm", "b34527202e6eb8cee198efec110996c25c5898f43a4094df157f8d28f27d9efe"},
   "earmark_parser": {:hex, :earmark_parser, "1.4.44", "f20830dd6b5c77afe2b063777ddbbff09f9759396500cdbe7523efd58d7a339c", [:mix], [], "hexpm", "4778ac752b4701a5599215f7030989c989ffdc4f6df457c5f36938cc2d2a2750"},
-  "ecto": {:hex, :ecto, "3.12.5", "4a312960ce612e17337e7cefcf9be45b95a3be6b36b6f94dfb3d8c361d631866", [:mix], [{:decimal, "~> 2.0", [hex: :decimal, repo: "hexpm", optional: false]}, {:jason, "~> 1.0", [hex: :jason, repo: "hexpm", optional: true]}, {:telemetry, "~> 0.4 or ~> 1.0", [hex: :telemetry, repo: "hexpm", optional: false]}], "hexpm", "6eb18e80bef8bb57e17f5a7f068a1719fbda384d40fc37acb8eb8aeca493b6ea"},
+  "ecto": {:hex, :ecto, "3.14.0", "2fa64521eebfcb2670d907a86e4ad947290e9933706bb315e6fb5c21b172cb26", [:mix], [{:decimal, "~> 3.0", [hex: :decimal, repo: "hexpm", optional: false]}, {:jason, "~> 1.0", [hex: :jason, repo: "hexpm", optional: true]}, {:telemetry, "~> 0.4 or ~> 1.0", [hex: :telemetry, repo: "hexpm", optional: false]}], "hexpm", "130d69ffb4285f9ce4792b65dfbb994fd13ea4cbc3cbea2524b199aa3de84af3"},
   "ecto_enum": {:hex, :ecto_enum, "1.4.0", "d14b00e04b974afc69c251632d1e49594d899067ee2b376277efd8233027aec8", [:mix], [{:ecto, ">= 3.0.0", [hex: :ecto, repo: "hexpm", optional: false]}, {:ecto_sql, "> 3.0.0", [hex: :ecto_sql, repo: "hexpm", optional: false]}, {:mariaex, ">= 0.0.0", [hex: :mariaex, repo: "hexpm", optional: true]}, {:postgrex, ">= 0.0.0", [hex: :postgrex, repo: "hexpm", optional: true]}], "hexpm", "8fb55c087181c2b15eee406519dc22578fa60dd82c088be376d0010172764ee4"},
-  "ecto_sql": {:hex, :ecto_sql, "3.12.1", "c0d0d60e85d9ff4631f12bafa454bc392ce8b9ec83531a412c12a0d415a3a4d0", [:mix], [{:db_connection, "~> 2.4.1 or ~> 2.5", [hex: :db_connection, repo: "hexpm", optional: false]}, {:ecto, "~> 3.12", [hex: :ecto, repo: "hexpm", optional: false]}, {:myxql, "~> 0.7", [hex: :myxql, repo: "hexpm", optional: true]}, {:postgrex, "~> 0.19 or ~> 1.0", [hex: :postgrex, repo: "hexpm", optional: true]}, {:tds, "~> 2.1.1 or ~> 2.2", [hex: :tds, repo: "hexpm", optional: true]}, {:telemetry, "~> 0.4.0 or ~> 1.0", [hex: :telemetry, repo: "hexpm", optional: false]}], "hexpm", "aff5b958a899762c5f09028c847569f7dfb9cc9d63bdb8133bff8a5546de6bf5"},
+  "ecto_sql": {:hex, :ecto_sql, "3.14.0", "06446ab8410d2f85bfbb80857ee224ab3b693700cbb38f6535d507449a627b2e", [:mix], [{:db_connection, "~> 2.9", [hex: :db_connection, repo: "hexpm", optional: false]}, {:decimal, "~> 3.0", [hex: :decimal, repo: "hexpm", optional: false]}, {:ecto, "~> 3.14.0", [hex: :ecto, repo: "hexpm", optional: false]}, {:myxql, "~> 0.8", [hex: :myxql, repo: "hexpm", optional: true]}, {:postgrex, "~> 0.19 or ~> 1.0", [hex: :postgrex, repo: "hexpm", optional: true]}, {:tds, "~> 2.1.1 or ~> 2.2", [hex: :tds, repo: "hexpm", optional: true]}, {:telemetry, "~> 0.4.0 or ~> 1.0", [hex: :telemetry, repo: "hexpm", optional: false]}], "hexpm", "f4d8d36faf294c9417b5a37ec7ac8217ee2abdef5fcf197ba690f361548d3949"},
   "elixir_make": {:hex, :elixir_make, "0.9.0", "6484b3cd8c0cee58f09f05ecaf1a140a8c97670671a6a0e7ab4dc326c3109726", [:mix], [], "hexpm", "db23d4fd8b757462ad02f8aa73431a426fe6671c80b200d9710caf3d1dd0ffdb"},
-  "ex_doc": {:hex, :ex_doc, "0.37.3", "f7816881a443cd77872b7d6118e8a55f547f49903aef8747dbcb345a75b462f9", [:mix], [{:earmark_parser, "~> 1.4.42", [hex: :earmark_parser, repo: "hexpm", optional: false]}, {:makeup_c, ">= 0.1.0", [hex: :makeup_c, repo: "hexpm", optional: true]}, {:makeup_elixir, "~> 0.14 or ~> 1.0", [hex: :makeup_elixir, repo: "hexpm", optional: false]}, {:makeup_erlang, "~> 0.1 or ~> 1.0", [hex: :makeup_erlang, repo: "hexpm", optional: false]}, {:makeup_html, ">= 0.1.0", [hex: :makeup_html, repo: "hexpm", optional: true]}], "hexpm", "e6aebca7156e7c29b5da4daa17f6361205b2ae5f26e5c7d8ca0d3f7e18972233"},
+  "erlex": {:hex, :erlex, "0.2.9", "7debbbaa9f4f368b8cd648983e0f1d7963028508e9c59e9d4ed504e94ef52a55", [:mix], [], "hexpm", "8cfffc0ec7159e6d73de2ab28a588064de80f88b2798d5cbe4482cbbc200178b"},
+  "ex_doc": {:hex, :ex_doc, "0.40.2", "f50edec428c4b0a457a167de42414c461122a3585a99515a69d09fff19e5597e", [:mix], [{:earmark_parser, "~> 1.4.44", [hex: :earmark_parser, repo: "hexpm", optional: false]}, {:makeup_c, ">= 0.1.0", [hex: :makeup_c, repo: "hexpm", optional: true]}, {:makeup_elixir, "~> 0.14 or ~> 1.0", [hex: :makeup_elixir, repo: "hexpm", optional: false]}, {:makeup_erlang, "~> 0.1 or ~> 1.0", [hex: :makeup_erlang, repo: "hexpm", optional: false]}, {:makeup_html, ">= 0.1.0", [hex: :makeup_html, repo: "hexpm", optional: true]}], "hexpm", "4fa426e2beb47854a162e2c488727fdec51cd4692e319b23810c2804cb1a40fe"},
   "ex_machina": {:hex, :ex_machina, "2.7.0", "b792cc3127fd0680fecdb6299235b4727a4944a09ff0fa904cc639272cd92dc7", [:mix], [{:ecto, "~> 2.2 or ~> 3.0", [hex: :ecto, repo: "hexpm", optional: true]}, {:ecto_sql, "~> 3.0", [hex: :ecto_sql, repo: "hexpm", optional: true]}], "hexpm", "419aa7a39bde11894c87a615c4ecaa52d8f107bbdd81d810465186f783245bf8"},
   "excoveralls": {:hex, :excoveralls, "0.18.5", "e229d0a65982613332ec30f07940038fe451a2e5b29bce2a5022165f0c9b157e", [:mix], [{:castore, "~> 1.0", [hex: :castore, repo: "hexpm", optional: true]}, {:jason, "~> 1.0", [hex: :jason, repo: "hexpm", optional: false]}], "hexpm", "523fe8a15603f86d64852aab2abe8ddbd78e68579c8525ae765facc5eae01562"},
-  "expo": {:hex, :expo, "1.1.0", "f7b9ed7fb5745ebe1eeedf3d6f29226c5dd52897ac67c0f8af62a07e661e5c75", [:mix], [], "hexpm", "fbadf93f4700fb44c331362177bdca9eeb8097e8b0ef525c9cc501cb9917c960"},
+  "expo": {:hex, :expo, "1.1.1", "4202e1d2ca6e2b3b63e02f69cfe0a404f77702b041d02b58597c00992b601db5", [:mix], [], "hexpm", "5fb308b9cb359ae200b7e23d37c76978673aa1b06e2b3075d814ce12c5811640"},
   "faker": {:hex, :faker, "0.18.0", "943e479319a22ea4e8e39e8e076b81c02827d9302f3d32726c5bf82f430e6e14", [:mix], [], "hexpm", "bfbdd83958d78e2788e99ec9317c4816e651ad05e24cfd1196ce5db5b3e81797"},
-  "file_system": {:hex, :file_system, "1.1.0", "08d232062284546c6c34426997dd7ef6ec9f8bbd090eb91780283c9016840e8f", [:mix], [], "hexpm", "bfcf81244f416871f2a2e15c1b515287faa5db9c6bcf290222206d120b3d43f6"},
-  "floki": {:hex, :floki, "0.37.1", "d7aaee758c8a5b4a7495799a4260754fec5530d95b9c383c03b27359dea117cf", [:mix], [], "hexpm", "673d040cb594d31318d514590246b6dd587ed341d3b67e17c1c0eb8ce7ca6f04"},
-  "gen_smtp": {:hex, :gen_smtp, "1.2.0", "9cfc75c72a8821588b9b9fe947ae5ab2aed95a052b81237e0928633a13276fd3", [:rebar3], [{:ranch, ">= 1.8.0", [hex: :ranch, repo: "hexpm", optional: false]}], "hexpm", "5ee0375680bca8f20c4d85f58c2894441443a743355430ff33a783fe03296779"},
+  "file_system": {:hex, :file_system, "1.1.1", "31864f4685b0148f25bd3fbef2b1228457c0c89024ad67f7a81a3ffbc0bbad3a", [:mix], [], "hexpm", "7a15ff97dfe526aeefb090a7a9d3d03aa907e100e262a0f8f7746b78f8f87a5d"},
+  "floki": {:hex, :floki, "0.38.2", "7b80245ff877bbf04ff4149b0389f43b3e8596f380af18420bd087eeb43ff9c8", [:mix], [], "hexpm", "854183daf5cb5f42a2d6b7e33f12f823329d9d36c648714adfee3515940e9716"},
+  "gen_smtp": {:hex, :gen_smtp, "1.3.0", "62c3d91f0dcf6ce9db71bcb6881d7ad0d1d834c7f38c13fa8e952f4104a8442e", [:rebar3], [{:ranch, ">= 1.8.0", [hex: :ranch, repo: "hexpm", optional: false]}], "hexpm", "0b73fbf069864ecbce02fe653b16d3f35fd889d0fdd4e14527675565c39d84e6"},
   "gettext": {:hex, :gettext, "0.26.2", "5978aa7b21fada6deabf1f6341ddba50bc69c999e812211903b169799208f2a8", [:mix], [{:expo, "~> 0.5.1 or ~> 1.0", [hex: :expo, repo: "hexpm", optional: false]}], "hexpm", "aa978504bcf76511efdc22d580ba08e2279caab1066b76bb9aa81c4a1e0a32a5"},
-  "hackney": {:hex, :hackney, "1.23.0", "55cc09077112bcb4a69e54be46ed9bc55537763a96cd4a80a221663a7eafd767", [:rebar3], [{:certifi, "~> 2.14.0", [hex: :certifi, repo: "hexpm", optional: false]}, {:idna, "~> 6.1.0", [hex: :idna, repo: "hexpm", optional: false]}, {:metrics, "~> 1.0.0", [hex: :metrics, repo: "hexpm", optional: false]}, {:mimerl, "~> 1.1", [hex: :mimerl, repo: "hexpm", optional: false]}, {:parse_trans, "3.4.1", [hex: :parse_trans, repo: "hexpm", optional: false]}, {:ssl_verify_fun, "~> 1.1.0", [hex: :ssl_verify_fun, repo: "hexpm", optional: false]}, {:unicode_util_compat, "~> 0.7.0", [hex: :unicode_util_compat, repo: "hexpm", optional: false]}], "hexpm", "6cd1c04cd15c81e5a493f167b226a15f0938a84fc8f0736ebe4ddcab65c0b44e"},
-  "html2markdown": {:hex, :html2markdown, "0.1.5", "703c6bd1bd7b93cc9ebd847970da11fba4a758b856da61469a2da1e0b3978e47", [:mix], [{:floki, ">= 0.36.2", [hex: :floki, repo: "hexpm", optional: false]}], "hexpm", "4bb0f19dd36d673992386aebf0d15de8baeb1173a73bee5f8dd9d6439868dbf0"},
-  "html_sanitize_ex": {:hex, :html_sanitize_ex, "1.4.3", "67b3d9fa8691b727317e0cc96b9b3093be00ee45419ffb221cdeee88e75d1360", [:mix], [{:mochiweb, "~> 2.15 or ~> 3.1", [hex: :mochiweb, repo: "hexpm", optional: false]}], "hexpm", "87748d3c4afe949c7c6eb7150c958c2bcba43fc5b2a02686af30e636b74bccb7"},
-  "hut": {:hex, :hut, "1.3.0", "71f2f054e657c03f959cf1acc43f436ea87580696528ca2a55c8afb1b06c85e7", [:"erlang.mk", :rebar, :rebar3], [], "hexpm", "7e15d28555d8a1f2b5a3a931ec120af0753e4853a4c66053db354f35bf9ab563"},
+  "hackney": {:hex, :hackney, "1.25.0", "390e9b83f31e5b325b9f43b76e1a785cbdb69b5b6cd4e079aa67835ded046867", [:rebar3], [{:certifi, "~> 2.15.0", [hex: :certifi, repo: "hexpm", optional: false]}, {:idna, "~> 6.1.0", [hex: :idna, repo: "hexpm", optional: false]}, {:metrics, "~> 1.0.0", [hex: :metrics, repo: "hexpm", optional: false]}, {:mimerl, "~> 1.4", [hex: :mimerl, repo: "hexpm", optional: false]}, {:parse_trans, "3.4.1", [hex: :parse_trans, repo: "hexpm", optional: false]}, {:ssl_verify_fun, "~> 1.1.0", [hex: :ssl_verify_fun, repo: "hexpm", optional: false]}, {:unicode_util_compat, "~> 0.7.1", [hex: :unicode_util_compat, repo: "hexpm", optional: false]}], "hexpm", "7209bfd75fd1f42467211ff8f59ea74d6f2a9e81cbcee95a56711ee79fd6b1d4"},
+  "html2markdown": {:hex, :html2markdown, "0.3.1", "c59aad7f29579c2b969bfa509dc31c86c1ee4571609932fa731cff692715d48d", [:mix], [{:floki, ">= 0.38.0", [hex: :floki, repo: "hexpm", optional: false]}], "hexpm", "da0f09a5a3eaa77a60870f81a72909f0ffe5a6f3404e193d91cbb6f0d0d31866"},
   "idna": {:hex, :idna, "6.1.1", "8a63070e9f7d0c62eb9d9fcb360a7de382448200fbbd1b106cc96d3d8099df8d", [:rebar3], [{:unicode_util_compat, "~> 0.7.0", [hex: :unicode_util_compat, repo: "hexpm", optional: false]}], "hexpm", "92376eb7894412ed19ac475e4a86f7b413c1b9fbb5bd16dccd57934157944cea"},
-  "jason": {:hex, :jason, "1.4.4", "b9226785a9aa77b6857ca22832cffa5d5011a667207eb2a0ad56adb5db443b8a", [:mix], [{:decimal, "~> 1.0 or ~> 2.0", [hex: :decimal, repo: "hexpm", optional: true]}], "hexpm", "c5eb0cab91f094599f94d55bc63409236a8ec69a21a67814529e8d5f6cc90b3b"},
+  "jason": {:hex, :jason, "1.4.5", "2e3a008590b0b8d7388c20293e9dcc9cf3e5d642fd2a114e4cbbb52e595d940a", [:mix], [{:decimal, "~> 1.0 or ~> 2.0 or ~> 3.0", [hex: :decimal, repo: "hexpm", optional: true]}], "hexpm", "b0c823996102bcd0239b3c2444eb00409b72f6a140c1950bc8b457d836b30684"},
   "makeup": {:hex, :makeup, "1.2.1", "e90ac1c65589ef354378def3ba19d401e739ee7ee06fb47f94c687016e3713d1", [:mix], [{:nimble_parsec, "~> 1.4", [hex: :nimble_parsec, repo: "hexpm", optional: false]}], "hexpm", "d36484867b0bae0fea568d10131197a4c2e47056a6fbe84922bf6ba71c8d17ce"},
   "makeup_elixir": {:hex, :makeup_elixir, "1.0.1", "e928a4f984e795e41e3abd27bfc09f51db16ab8ba1aebdba2b3a575437efafc2", [:mix], [{:makeup, "~> 1.0", [hex: :makeup, repo: "hexpm", optional: false]}, {:nimble_parsec, "~> 1.2.3 or ~> 1.3", [hex: :nimble_parsec, repo: "hexpm", optional: false]}], "hexpm", "7284900d412a3e5cfd97fdaed4f5ed389b8f2b4cb49efc0eb3bd10e2febf9507"},
-  "makeup_erlang": {:hex, :makeup_erlang, "1.0.2", "03e1804074b3aa64d5fad7aa64601ed0fb395337b982d9bcf04029d68d51b6a7", [:mix], [{:makeup, "~> 1.0", [hex: :makeup, repo: "hexpm", optional: false]}], "hexpm", "af33ff7ef368d5893e4a267933e7744e46ce3cf1f61e2dccf53a111ed3aa3727"},
+  "makeup_erlang": {:hex, :makeup_erlang, "1.1.0", "835f7e60792e08824cda445639555d7bf1bbbddb1b60b306e33cb6f6db24dc74", [:mix], [{:makeup, "~> 1.0", [hex: :makeup, repo: "hexpm", optional: false]}], "hexpm", "1cd6780fb1dd1a03979abaed0fe82712b0625118fd5257d3ebbf73f960c73c3c"},
   "metrics": {:hex, :metrics, "1.0.1", "25f094dea2cda98213cecc3aeff09e940299d950904393b2a29d191c346a8486", [:rebar3], [], "hexpm", "69b09adddc4f74a40716ae54d140f93beb0fb8978d8636eaded0c31b6f099f16"},
-  "mime": {:hex, :mime, "2.0.6", "8f18486773d9b15f95f4f4f1e39b710045fa1de891fada4516559967276e4dc2", [:mix], [], "hexpm", "c9945363a6b26d747389aac3643f8e0e09d30499a138ad64fe8fd1d13d9b153e"},
-  "mimerl": {:hex, :mimerl, "1.3.0", "d0cd9fc04b9061f82490f6581e0128379830e78535e017f7780f37fea7545726", [:rebar3], [], "hexpm", "a1e15a50d1887217de95f0b9b0793e32853f7c258a5cd227650889b38839fe9d"},
-  "mix_test_watch": {:hex, :mix_test_watch, "1.2.0", "1f9acd9e1104f62f280e30fc2243ae5e6d8ddc2f7f4dc9bceb454b9a41c82b42", [:mix], [{:file_system, "~> 0.2 or ~> 1.0", [hex: :file_system, repo: "hexpm", optional: false]}], "hexpm", "278dc955c20b3fb9a3168b5c2493c2e5cffad133548d307e0a50c7f2cfbf34f6"},
-  "mochiweb": {:hex, :mochiweb, "3.2.2", "bb435384b3b9fd1f92f2f3fe652ea644432877a3e8a81ed6459ce951e0482ad3", [:rebar3], [], "hexpm", "4114e51f1b44c270b3242d91294fe174ce1ed989100e8b65a1fab58e0cba41d5"},
+  "mime": {:hex, :mime, "2.0.7", "b8d739037be7cd402aee1ba0306edfdef982687ee7e9859bee6198c1e7e2f128", [:mix], [], "hexpm", "6171188e399ee16023ffc5b76ce445eb6d9672e2e241d2df6050f3c771e80ccd"},
+  "mimerl": {:hex, :mimerl, "1.5.0", "f35aca6f23242339b3666e0ac0702379e362b469d0aea167f6cc713547e777ed", [:rebar3], [], "hexpm", "db648ce065bae14ea84ca8b5dd123f42f49417cef693541110bf6f9e9be9ecc4"},
+  "mix_test_watch": {:hex, :mix_test_watch, "1.4.0", "d88bcc4fbe3198871266e9d2f00cd8ae350938efbb11d3fa1da091586345adbb", [:mix], [{:file_system, "~> 0.2 or ~> 1.0", [hex: :file_system, repo: "hexpm", optional: false]}], "hexpm", "2b4693e17c8ead2ef56d4f48a0329891e8c2d0d73752c0f09272a2b17dc38d1b"},
   "nimble_parsec": {:hex, :nimble_parsec, "1.4.2", "8efba0122db06df95bfaa78f791344a89352ba04baedd3849593bfce4d0dc1c6", [:mix], [], "hexpm", "4b21398942dda052b403bbe1da991ccd03a053668d147d53fb8c4e0efe09c973"},
-  "parallel_stream": {:hex, :parallel_stream, "1.1.0", "f52f73eb344bc22de335992377413138405796e0d0ad99d995d9977ac29f1ca9", [:mix], [], "hexpm", "684fd19191aedfaf387bbabbeb8ff3c752f0220c8112eb907d797f4592d6e871"},
   "parse_trans": {:hex, :parse_trans, "3.4.1", "6e6aa8167cb44cc8f39441d05193be6e6f4e7c2946cb2759f015f8c56b76e5ff", [:rebar3], [], "hexpm", "620a406ce75dada827b82e453c19cf06776be266f5a67cff34e1ef2cbb60e49a"},
-  "plug": {:hex, :plug, "1.14.2", "cff7d4ec45b4ae176a227acd94a7ab536d9b37b942c8e8fa6dfc0fff98ff4d80", [:mix], [{:mime, "~> 1.0 or ~> 2.0", [hex: :mime, repo: "hexpm", optional: false]}, {:plug_crypto, "~> 1.1.1 or ~> 1.2", [hex: :plug_crypto, repo: "hexpm", optional: false]}, {:telemetry, "~> 0.4.3 or ~> 1.0", [hex: :telemetry, repo: "hexpm", optional: false]}], "hexpm", "842fc50187e13cf4ac3b253d47d9474ed6c296a8732752835ce4a86acdf68d13"},
-  "plug_crypto": {:hex, :plug_crypto, "1.2.5", "918772575e48e81e455818229bf719d4ab4181fcbf7f85b68a35620f78d89ced", [:mix], [], "hexpm", "26549a1d6345e2172eb1c233866756ae44a9609bd33ee6f99147ab3fd87fd842"},
-  "puid": {:hex, :puid, "2.3.2", "6828b32e331d668f155f9b48727c7292341a85f248876826f817efaa70246964", [:mix], [], "hexpm", "10489d3071a8736097ac79e8fcf644bc483912b1a197f02e239ebcc5b5276a83"},
+  "postgrex": {:hex, :postgrex, "0.22.2", "4aec14df2a72722aee92492566edbeeb44e233ecb86b1915d03136297ef1385d", [:mix], [{:db_connection, "~> 2.9", [hex: :db_connection, repo: "hexpm", optional: false]}, {:decimal, "~> 1.5 or ~> 2.0 or ~> 3.0", [hex: :decimal, repo: "hexpm", optional: false]}, {:jason, "~> 1.0", [hex: :jason, repo: "hexpm", optional: true]}, {:table, "~> 0.1.0", [hex: :table, repo: "hexpm", optional: true]}], "hexpm", "8946382ddb06294f56026ac4278b3cc212bac8a2c82ed68b4087819ed1abc53b"},
+  "puid": {:hex, :puid, "2.7.1", "01ca7e0f99e292007c61f5bddeac0f640c99cf977141dd87817d380a385f327e", [:mix], [], "hexpm", "0ade2cf1b0bb61057a326e46b6a056110f6598562e71f55619420abb3b7a99a3"},
   "ranch": {:hex, :ranch, "2.2.0", "25528f82bc8d7c6152c57666ca99ec716510fe0925cb188172f41ce93117b1b0", [:make, :rebar3], [], "hexpm", "fa0b99a1780c80218a4197a59ea8d3bdae32fbff7e88527d7d8a4787eff4f8e7"},
-  "rivet": {:hex, :rivet, "2.5.1", "c8db2a1ce9a693beeab4ee459f253716ff84712873aea59fab45cb07da769d15", [:mix], [{:ecto_enum, "~> 1.0", [hex: :ecto_enum, repo: "hexpm", optional: false]}, {:ecto_sql, "~> 3.9", [hex: :ecto_sql, repo: "hexpm", optional: false]}, {:rivet_utils, "~> 2.0.3", [hex: :rivet_utils, repo: "hexpm", optional: false]}, {:timex, "~> 3.7", [hex: :timex, repo: "hexpm", optional: false]}, {:transmogrify, "~> 2.0.2", [hex: :transmogrify, repo: "hexpm", optional: false]}, {:typed_ecto_schema, "~> 0.3.0 or ~> 0.4.1", [hex: :typed_ecto_schema, repo: "hexpm", optional: false]}, {:yaml_elixir, "~> 2.8", [hex: :yaml_elixir, repo: "hexpm", optional: false]}], "hexpm", "957944661993b068862452f34328794df97d4178ed22855daf3e77ac9cc9388f"},
-  "rivet_email_devel": {:git, "git@github.com:srevenant/rivet-email-devel", "c6cfa0561a2cacb94765f05c2607aebae10097d8", [branch: "master"]},
-  "rivet_utils": {:hex, :rivet_utils, "2.0.6", "86fb7c20f28d0077cbba29165f5d58b39db058363092709e4a393174f09edbe5", [:mix], [{:bcrypt_elixir, "~> 3.0", [hex: :bcrypt_elixir, repo: "hexpm", optional: false]}, {:ecto, "~> 3.7", [hex: :ecto, repo: "hexpm", optional: false]}, {:jason, "~> 1.0", [hex: :jason, repo: "hexpm", optional: false]}, {:puid, "~> 2.0", [hex: :puid, repo: "hexpm", optional: false]}, {:transmogrify, "~> 2.0.2", [hex: :transmogrify, repo: "hexpm", optional: false]}], "hexpm", "60864501008cc81e049709c2aa5d7cb55d0f90baa008dd51748e5a50dbb8fd7a"},
+  "rivet": {:hex, :rivet, "2.7.1", "eb62e40b3be0d2179b3175a7bf20d0169baf5cf08f04efe1eed9eaa60b823578", [:mix], [{:ecto_enum, "~> 1.4", [hex: :ecto_enum, repo: "hexpm", optional: false]}, {:ecto_sql, "~> 3.13", [hex: :ecto_sql, repo: "hexpm", optional: false]}, {:rivet_utils, "~> 2.0", [hex: :rivet_utils, repo: "hexpm", optional: false]}, {:transmogrify, "~> 2.0", [hex: :transmogrify, repo: "hexpm", optional: false]}, {:typed_ecto_schema, "~> 0.4", [hex: :typed_ecto_schema, repo: "hexpm", optional: false]}, {:yaml_elixir, "~> 2.12", [hex: :yaml_elixir, repo: "hexpm", optional: false]}], "hexpm", "3f8954ae746a08e52b8db4d96d60e909ae4140d29dff8ca449dd21972c62e056"},
+  "rivet_utils": {:hex, :rivet_utils, "2.6.0", "c22dbea2808f887beab659ee14e26d56658b0c50c1126ec338f1b1d458b2b634", [:mix], [{:bcrypt_elixir, "~> 3.0", [hex: :bcrypt_elixir, repo: "hexpm", optional: false]}, {:ecto, "~> 3.13", [hex: :ecto, repo: "hexpm", optional: false]}, {:jason, "~> 1.0", [hex: :jason, repo: "hexpm", optional: false]}, {:puid, "~> 2.0", [hex: :puid, repo: "hexpm", optional: false]}, {:transmogrify, "~> 2.0.2", [hex: :transmogrify, repo: "hexpm", optional: false]}], "hexpm", "4272e8fbd7df17c309f99a519d9d6ebb86235115ada6eb781fb9ec40d124d869"},
   "ssl_verify_fun": {:hex, :ssl_verify_fun, "1.1.7", "354c321cf377240c7b8716899e182ce4890c5938111a1296add3ec74cf1715df", [:make, :mix, :rebar3], [], "hexpm", "fe4c190e8f37401d30167c8c405eda19469f34577987c76dde613e838bbc67f8"},
-  "swoosh": {:hex, :swoosh, "1.19.0", "b2d62ed899faba6a499bbc19dd8e09452121133a6c8c2c867fc38e37c811c890", [:mix], [{:bandit, ">= 1.0.0", [hex: :bandit, repo: "hexpm", optional: true]}, {:cowboy, "~> 1.1 or ~> 2.4", [hex: :cowboy, repo: "hexpm", optional: true]}, {:ex_aws, "~> 2.1", [hex: :ex_aws, repo: "hexpm", optional: true]}, {:finch, "~> 0.6", [hex: :finch, repo: "hexpm", optional: true]}, {:gen_smtp, "~> 0.13 or ~> 1.0", [hex: :gen_smtp, repo: "hexpm", optional: true]}, {:hackney, "~> 1.9", [hex: :hackney, repo: "hexpm", optional: true]}, {:jason, "~> 1.0", [hex: :jason, repo: "hexpm", optional: false]}, {:mail, "~> 0.2", [hex: :mail, repo: "hexpm", optional: true]}, {:mime, "~> 1.1 or ~> 2.0", [hex: :mime, repo: "hexpm", optional: false]}, {:mua, "~> 0.2.3", [hex: :mua, repo: "hexpm", optional: true]}, {:multipart, "~> 0.4", [hex: :multipart, repo: "hexpm", optional: true]}, {:plug, "~> 1.9", [hex: :plug, repo: "hexpm", optional: true]}, {:plug_cowboy, ">= 1.0.0", [hex: :plug_cowboy, repo: "hexpm", optional: true]}, {:req, "~> 0.5.10 or ~> 0.6 or ~> 1.0", [hex: :req, repo: "hexpm", optional: true]}, {:telemetry, "~> 0.4.2 or ~> 1.0", [hex: :telemetry, repo: "hexpm", optional: false]}], "hexpm", "e4ab3fd9dd69db4c89c518c62a8a8f2b879a4885bdcbcbc4be46b6b5381e9f12"},
-  "telemetry": {:hex, :telemetry, "1.3.0", "fedebbae410d715cf8e7062c96a1ef32ec22e764197f70cda73d82778d61e7a2", [:rebar3], [], "hexpm", "7015fc8919dbe63764f4b4b87a95b7c0996bd539e0d499be6ec9d7f3875b79e6"},
-  "timex": {:hex, :timex, "3.7.11", "bb95cb4eb1d06e27346325de506bcc6c30f9c6dea40d1ebe390b262fad1862d1", [:mix], [{:combine, "~> 0.10", [hex: :combine, repo: "hexpm", optional: false]}, {:gettext, "~> 0.20", [hex: :gettext, repo: "hexpm", optional: false]}, {:tzdata, "~> 1.1", [hex: :tzdata, repo: "hexpm", optional: false]}], "hexpm", "8b9024f7efbabaf9bd7aa04f65cf8dcd7c9818ca5737677c7b76acbc6a94d1aa"},
+  "swoosh": {:hex, :swoosh, "1.25.2", "cd3e53b0391439395492e5dce8c22288733f22603e21136162d03cd153669be9", [:mix], [{:bandit, ">= 1.0.0", [hex: :bandit, repo: "hexpm", optional: true]}, {:cowboy, "~> 1.1 or ~> 2.4", [hex: :cowboy, repo: "hexpm", optional: true]}, {:ex_aws, "~> 2.1", [hex: :ex_aws, repo: "hexpm", optional: true]}, {:finch, "~> 0.6", [hex: :finch, repo: "hexpm", optional: true]}, {:gen_smtp, "~> 0.13 or ~> 1.0", [hex: :gen_smtp, repo: "hexpm", optional: true]}, {:hackney, "~> 1.9", [hex: :hackney, repo: "hexpm", optional: true]}, {:idna, "~> 6.0", [hex: :idna, repo: "hexpm", optional: false]}, {:jason, "~> 1.0", [hex: :jason, repo: "hexpm", optional: false]}, {:mail, "~> 0.2", [hex: :mail, repo: "hexpm", optional: true]}, {:mime, "~> 1.1 or ~> 2.0", [hex: :mime, repo: "hexpm", optional: false]}, {:mua, "~> 0.2.3", [hex: :mua, repo: "hexpm", optional: true]}, {:multipart, "~> 0.4", [hex: :multipart, repo: "hexpm", optional: true]}, {:plug, "~> 1.9", [hex: :plug, repo: "hexpm", optional: true]}, {:plug_cowboy, ">= 1.0.0", [hex: :plug_cowboy, repo: "hexpm", optional: true]}, {:req, "~> 0.5.10 or ~> 0.6 or ~> 1.0", [hex: :req, repo: "hexpm", optional: true]}, {:telemetry, "~> 0.4.2 or ~> 1.0", [hex: :telemetry, repo: "hexpm", optional: false]}], "hexpm", "0aecf65b2845f13f4d440e0945715432bbde2d815e2302adf7df549cd9bdafed"},
+  "telemetry": {:hex, :telemetry, "1.4.2", "a0cb522801dffb1c49fe6e30561badffc7b6d0e180db1300df759faa22062855", [:rebar3], [], "hexpm", "928f6495066506077862c0d1646609eed891a4326bee3126ba54b60af61febb1"},
+  "timex": {:hex, :timex, "3.7.13", "0688ce11950f5b65e154e42b47bf67b15d3bc0e0c3def62199991b8a8079a1e2", [:mix], [{:combine, "~> 0.10", [hex: :combine, repo: "hexpm", optional: false]}, {:gettext, "~> 0.26", [hex: :gettext, repo: "hexpm", optional: false]}, {:tzdata, "~> 1.1", [hex: :tzdata, repo: "hexpm", optional: false]}], "hexpm", "09588e0522669328e973b8b4fd8741246321b3f0d32735b589f78b136e6d4c54"},
   "transmogrify": {:hex, :transmogrify, "2.0.2", "365b361b412f8bdf55952f501ad49e9c4cd258980e35d780e7398dbd474f6242", [:mix], [], "hexpm", "d3101681c2791624533c861bb7a992b6944a585300d1db19357d7cad15e6a8c5"},
-  "typed_ecto_schema": {:hex, :typed_ecto_schema, "0.4.1", "a373ca6f693f4de84cde474a67467a9cb9051a8a7f3f615f1e23dc74b75237fa", [:mix], [{:ecto, "~> 3.5", [hex: :ecto, repo: "hexpm", optional: false]}], "hexpm", "85c6962f79d35bf543dd5659c6adc340fd2480cacc6f25d2cc2933ea6e8fcb3b"},
+  "typed_ecto_schema": {:hex, :typed_ecto_schema, "0.4.3", "1e5f3b6c763f9b5725975d3ab7f1554525f1f1399b966f2425acf04f9d8dd4fe", [:mix], [{:ecto, "~> 3.5", [hex: :ecto, repo: "hexpm", optional: false]}], "hexpm", "dcbd9b35b9fda5fa9258e0ae629a99cf4473bd7adfb85785d3f71dfe7a9b2bc0"},
   "tzdata": {:hex, :tzdata, "1.1.3", "b1cef7bb6de1de90d4ddc25d33892b32830f907e7fc2fccd1e7e22778ab7dfbc", [:mix], [{:hackney, "~> 1.17", [hex: :hackney, repo: "hexpm", optional: false]}], "hexpm", "d4ca85575a064d29d4e94253ee95912edfb165938743dbf002acdf0dcecb0c28"},
-  "unicode_util_compat": {:hex, :unicode_util_compat, "0.7.0", "bc84380c9ab48177092f43ac89e4dfa2c6d62b40b8bd132b1059ecc7232f9a78", [:rebar3], [], "hexpm", "25eee6d67df61960cf6a794239566599b09e17e668d3700247bc498638152521"},
+  "unicode_util_compat": {:hex, :unicode_util_compat, "0.7.1", "a48703a25c170eedadca83b11e88985af08d35f37c6f664d6dcfb106a97782fc", [:rebar3], [], "hexpm", "b3a917854ce3ae233619744ad1e0102e05673136776fb2fa76234f3e03b23642"},
   "yamerl": {:hex, :yamerl, "0.10.0", "4ff81fee2f1f6a46f1700c0d880b24d193ddb74bd14ef42cb0bcf46e81ef2f8e", [:rebar3], [], "hexpm", "346adb2963f1051dc837a2364e4acf6eb7d80097c0f53cbdc3046ec8ec4b4e6e"},
-  "yaml_elixir": {:hex, :yaml_elixir, "2.11.0", "9e9ccd134e861c66b84825a3542a1c22ba33f338d82c07282f4f1f52d847bd50", [:mix], [{:yamerl, "~> 0.10", [hex: :yamerl, repo: "hexpm", optional: false]}], "hexpm", "53cc28357ee7eb952344995787f4bb8cc3cecbf189652236e9b163e8ce1bc242"},
+  "yaml_elixir": {:hex, :yaml_elixir, "2.12.1", "d74f2d82294651b58dac849c45a82aaea639766797359baff834b64439f6b3f4", [:mix], [{:yamerl, "~> 0.10", [hex: :yamerl, repo: "hexpm", optional: false]}], "hexpm", "d9ac16563c737d55f9bfeed7627489156b91268a3a21cd55c54eb2e335207fed"},
 }
diff --git a/priv/rivet/migrations/config/base.exs b/priv/rivet/migrations/config/base.exs
new file mode 100644
index 0000000..dab6696
--- /dev/null
+++ b/priv/rivet/migrations/config/base.exs
@@ -0,0 +1,17 @@
+defmodule Rivet.Email.Config.Migrations.Base do
+  @moduledoc false
+  use Ecto.Migration
+
+  def change do
+    create table(:email_configs, primary_key: false) do
+      add(:id, :uuid, primary_key: true)
+      add(:site, :string, null: false)
+      add(:group, :string, null: false)
+      add(:key, :string, null: false)
+      add(:value, :map, null: false)
+      timestamps()
+    end
+    create(unique_index(:email_configs, [:site, :group, :key]))
+  end
+
+end
diff --git a/priv/rivet/migrations/config/index.exs b/priv/rivet/migrations/config/index.exs
new file mode 100644
index 0000000..aabee45
--- /dev/null
+++ b/priv/rivet/migrations/config/index.exs
@@ -0,0 +1,5 @@
+alias Rivet.Email.Config.Migrations, as: M
+
+[
+  [base: true, version: 0, module: M.Base]
+]
diff --git a/priv/rivet/migrations/migrations.exs b/priv/rivet/migrations/migrations.exs
index 5d7cb46..eaac9c4 100644
--- a/priv/rivet/migrations/migrations.exs
+++ b/priv/rivet/migrations/migrations.exs
@@ -1,3 +1,4 @@
 [
-  [include: "template", prefix: 220]
+  [include: "template", prefix: 220],
+  [include: "config", prefix: 221]
 ]
diff --git a/priv/rivet/migrations/template/archive.exs b/priv/rivet/migrations/template/archive.exs
deleted file mode 100644
index fe51488..0000000
--- a/priv/rivet/migrations/template/archive.exs
+++ /dev/null
@@ -1 +0,0 @@
-[]
diff --git a/priv/rivet/migrations/template/base.exs b/priv/rivet/migrations/template/base.exs
index 17854a4..cf02e99 100644
--- a/priv/rivet/migrations/template/base.exs
+++ b/priv/rivet/migrations/template/base.exs
@@ -5,8 +5,8 @@ defmodule Rivet.Email.Template.Migrations.Base do
   def change do
     create table(:email_templates, primary_key: false) do
       add(:id, :uuid, primary_key: true)
-      add(:name, :string)
-      add(:data, :text)
+      add(:name, :string, default: "")
+      add(:data, :text, default: "")
       timestamps()
     end
   end
diff --git a/priv/rivet/migrations/template/data.exs b/priv/rivet/migrations/template/data.exs
deleted file mode 100644
index 8f0691a..0000000
--- a/priv/rivet/migrations/template/data.exs
+++ /dev/null
@@ -1,13 +0,0 @@
-defmodule Rivet.Email.Template.Migrations.Data do
-  @moduledoc false
-  use Ecto.Migration
-
-  def change do
-    create table(:email_template_data, primary_key: false) do
-      add(:id, :uuid, primary_key: true)
-      add(:name, :string, null: false)
-      add(:site, :string)
-      add(:data, :map)
-    end
-  end
-end
diff --git a/priv/rivet/migrations/template/index.exs b/priv/rivet/migrations/template/index.exs
index 48e92b8..ce89966 100644
--- a/priv/rivet/migrations/template/index.exs
+++ b/priv/rivet/migrations/template/index.exs
@@ -1,5 +1,6 @@
 alias Rivet.Email.Template.Migrations, as: M
 
 [
+  [version: 1, module: M.V01Index],
   [base: true, version: 0, module: M.Base]
 ]
diff --git a/priv/rivet/migrations/template/v01_index.exs b/priv/rivet/migrations/template/v01_index.exs
new file mode 100644
index 0000000..1dbfd1a
--- /dev/null
+++ b/priv/rivet/migrations/template/v01_index.exs
@@ -0,0 +1,8 @@
+defmodule Rivet.Email.Template.Migrations.V01Index do
+  @moduledoc false
+  use Ecto.Migration
+
+  def change do
+    create_if_not_exists(unique_index(:email_templates, [:name]))
+  end
+end
diff --git a/test/case.ex b/test/case.ex
deleted file mode 100644
index 6d64035..0000000
--- a/test/case.ex
+++ /dev/null
@@ -1,9 +0,0 @@
-defmodule Rivet.Email.Case do
-  use ExUnit.CaseTemplate
-
-  using do
-    quote location: :keep do
-      import Rivet.Email.Case
-    end
-  end
-end
diff --git a/test/email/config_test.exs b/test/email/config_test.exs
new file mode 100644
index 0000000..0893a9d
--- /dev/null
+++ b/test/email/config_test.exs
@@ -0,0 +1,28 @@
+defmodule Test.Rivet.Email.ConfigTest do
+  use Test.Support.Email.Case
+  alias Rivet.Email.Example.Mailer
+  alias Mailer.Configurator
+  alias Rivet.Email.Config
+
+  test "config test" do
+    # clear cache of any other tests data
+    Configurator.clear()
+    assert [] = Config.all!()
+
+    {:ok, %Config{id: id, site: "", group: "addr", key: "boop", value: "somefin"}} =
+      Config.set("addr", "boop", "somefin")
+
+    # change the value and also test list/string email tuples
+    {:ok, %Config{id: ^id, value: ["a", "b"]}} = Config.set("addr", "boop", ["a", "b"])
+
+    {:error, %{valid?: false, errors: [value: {"is invalid", _}]}} = Config.set("addr", "boop", 1)
+
+    assert {:error, :not_found} = Configurator.conf("spleen", "boop")
+
+    assert {:ok, %Config{}} = Config.set("spleen", "boop", "sploop")
+
+    assert {:ok, "sploop"} = Configurator.conf("spleen", "boop")
+
+    assert {:ok, %{spleen: %{boop: "sploop"}}} = Configurator.load_site("")
+  end
+end
diff --git a/test/eval_template_test.exs b/test/email/eval_template_test.exs
similarity index 93%
rename from test/eval_template_test.exs
rename to test/email/eval_template_test.exs
index 82825c5..cb839a0 100644
--- a/test/eval_template_test.exs
+++ b/test/email/eval_template_test.exs
@@ -1,5 +1,5 @@
-defmodule Rivet.Email.EvalTemplateTest do
-  use ExUnit.Case
+defmodule Test.Rivet.Email.EvalTemplateTest do
+  use Test.Support.Email.Case
 
   doctest Rivet.Email.Template, import: true
   doctest Rivet.Email.Template.Helpers, import: true
diff --git a/test/email/send_test.exs b/test/email/send_test.exs
new file mode 100644
index 0000000..63c8438
--- /dev/null
+++ b/test/email/send_test.exs
@@ -0,0 +1,43 @@
+defmodule Test.Rivet.Email.SendTest do
+  use Test.Support.Email.Case
+  import ExUnit.CaptureLog
+  alias Rivet.Email.Example.Mailer
+
+  describe "tests" do
+    setup do
+      assert {:ok, _} =
+               Rivet.Email.Template.create(%{name: "//CONFIG/narf", data: "{\"boop\": 1}"})
+
+      :ok
+    end
+
+    test "send via template" do
+      assert capture_log(fn ->
+               assert {:ok, ["test delivered"]} =
+                        Mailer.Template.sendto(Mailer.User.mock(), tester: "testing")
+             end) =~ ~r/Subject: test subject/
+    end
+
+    test "send" do
+      %{emails: [em]} = Mailer.User.mock()
+      erred = %{em | address: "error@error"}
+
+      assert {:error, "Sender email address is missing from assigns (@email_from)"} =
+               Mailer.sendto(em, Mailer.Template)
+
+      from = [email_from: "nobody@nobody"]
+
+      assert {:error, "Cannot send email without recipient!"} =
+               Mailer.sendto([], Mailer.Template, from)
+
+      assert {:error, "test error", _} =
+               Mailer.sendto(erred, Mailer.Template, from, ["narf"])
+
+      ## something about the test adapter isn't supporting the name+email structure like this,
+      ## so skip the test for now...
+      # assert {:ok, ["test delivered"]} =
+      #          Mailer.sendto(em, Mailer.Template, [email_from: ["boop", "nobody@nobody"]])
+      assert {:ok, ["test delivered"]} = Mailer.sendto(em, Mailer.Template, from, [])
+    end
+  end
+end
diff --git a/test/email_test.exs b/test/email_test.exs
deleted file mode 100644
index 6671d0a..0000000
--- a/test/email_test.exs
+++ /dev/null
@@ -1,14 +0,0 @@
-defmodule Rivet.Email.Test do
-  use ExUnit.Case
-  import ExUnit.CaptureLog
-  alias Rivet.Email.Example.Mailer
-
-  doctest Rivet.Email, import: true
-
-  test "send via template" do
-    assert capture_log(fn ->
-             assert {:ok, ["email disabled"]} =
-                      Mailer.Template.sendto(Mailer.User.mock(), tester: "testing")
-           end) =~ ~r/Subject: test subject/
-  end
-end
diff --git a/test/support/email/case.ex b/test/support/email/case.ex
new file mode 100644
index 0000000..50eda9a
--- /dev/null
+++ b/test/support/email/case.ex
@@ -0,0 +1,24 @@
+defmodule Test.Support.Email.Case do
+  use ExUnit.CaseTemplate
+
+  using do
+    quote location: :keep do
+      import Ecto
+      import Ecto.Changeset
+      import Ecto.Query
+      # import Rivet.Email.Case
+      alias Rivet.Email.Repo
+      alias Ecto.Changeset
+    end
+  end
+
+  setup tags do
+    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Rivet.Email.Repo, [])
+
+    unless tags[:async] do
+      Ecto.Adapters.SQL.Sandbox.mode(Rivet.Email.Repo, {:shared, self()})
+    end
+
+    :ok
+  end
+end
diff --git a/test/support/test_adapter.ex b/test/support/test_adapter.ex
new file mode 100644
index 0000000..610af98
--- /dev/null
+++ b/test/support/test_adapter.ex
@@ -0,0 +1,39 @@
+defmodule Rivet.Email.Swoosh.Adapter.Test do
+  use Swoosh.Adapter
+  require Logger
+
+  def deliver(%Swoosh.Email{to: [{_, eaddr}], subject: subj} = email, _config) do
+    # for pid <- pids() do
+    #   send(pid, {:email, email})
+    # end
+    #
+    if eaddr === "error@error" do
+      {:error, "test error"}
+    else
+      Logger.warning("Testing send message to #{inspect(eaddr)}", subject: subj)
+      Rivet.Email.log_email(email)
+
+      {:ok, "test delivered"}
+    end
+  end
+
+  #
+  # def deliver_many(emails, _config) do
+  #   # for pid <- pids() do
+  #   #   send(pid, {:emails, emails})
+  #   # end
+  #
+  #   responses = for _email <- emails, do: "test delivered"
+  #
+  #   {:ok, responses}
+  # end
+  # Essentially finds all of the processes that tried to send an email (in the test)
+  # and sends an email to that process.
+  # defp pids do
+  #   if pid = Application.get_env(:swoosh, :shared_test_process) do
+  #     [pid]
+  #   else
+  #     Enum.uniq([self() | List.wrap(Process.get(:"$callers"))])
+  #   end
+  # end
+end
diff --git a/test/test_helper.exs b/test/test_helper.exs
index 1d9ad74..7b38c7e 100644
--- a/test/test_helper.exs
+++ b/test/test_helper.exs
@@ -1,5 +1,20 @@
-ExUnit.start(capture_log: false)
-{:ok, _} = Application.ensure_all_started(:ex_machina)
+# ExUnit.start(capture_log: false)
+# {:ok, _} = Application.ensure_all_started(:ex_machina)
 
-ExUnit.configure(exclude: [pending: true], formatters: [JUnitFormatter, ExUnit.CLIFormatter])
-Faker.start()
+children = [
+  {Rivet.Email.Repo, []},
+  Rivet.Email.Example.Mailer.Configurator
+]
+
+Supervisor.start_link(children, strategy: :one_for_one, name: Test.Supervisor)
+
+# ExUnit.configure(exclude: [pending: true], formatters: [JUnitFormatter, ExUnit.CLIFormatter])
+# Faker.start()
+
+ExUnit.start(
+  exclude: [:skip],
+  capture_log: true,
+  formatters: [JUnitFormatter, ExUnit.CLIFormatter]
+)
+
+Ecto.Adapters.SQL.Sandbox.mode(Rivet.Email.Repo, :auto)
