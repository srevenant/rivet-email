defmodule Rivet.Email.Template do
  @callback generate(recipient :: map(), attributes :: map()) ::
              {:ok, subject :: String.t(), html_body :: String.t()}
  @callback sendto(recipients :: any(), assigns :: list()) :: :ok

  use TypedEctoSchema
  use Rivet.Ecto.Model

  typed_schema "email_templates" do
    field(:name, Rivet.Utils.Ecto.Atom)
    field(:data, :string)
    timestamps()
  end

  use Rivet.Ecto.Collection,
    required: [:name],
    update: [:data, :name],
    unique_constraints: [:name]

  @doc ~S"""
  iex> html2text("<b>an html doc</b><p><h1>Header</h1>")
  "an html doc\r\n\r\n\r\n# Header\r\n"
  """
  @spec html2text(html :: String.t()) :: text :: String.t()
  def html2text(html) do
    # doesn't have to be pretty, very few will actually see it
    html
    |> preserve_links()
    |> String.replace(~r/<\s*h(.)\s*>/im, "\r\n\r\n# ", global: true)
    |> String.replace(~r/<\/\s*h(.)\s*>/im, "\r\n", global: true)
    |> String.replace(~r/<li>/im, "\\g{1}- ", global: true)
    |> String.replace(~r/<\/?\s*(br|p|div|h.)\s*\/?>/im, "\r\n", global: true)
    |> HtmlSanitizeEx.strip_tags()
  end

  @doc ~S"""
  iex> preserve_links("<a href=\"foo\">bar</a> baz <a href=\"narf\">bork</a>.")
  "bar<foo> baz bork<narf>."
  iex> preserve_links("<a href=\"foo\">bar</a> baz")
  "bar<foo> baz"
  """
  def preserve_links(str) do
    Regex.replace(
      ~r/<a[^>]+href="([^"]+)">([^<]+)<\/a>/,
      str,
      fn _, url, text -> "#{text}<#{url}>" end
    )
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      require Logger
      @assigns Keyword.get(opts, :assigns, false)
      @configs Keyword.get(opts, :configs, ["site"])
      @behaviour Rivet.Email.Template
      @tname Atom.to_string(__MODULE__)

      # future: for scale of thousands/second, add a read-through cache with Rivet lazy cache
      def load_and_eval(email, assigns) do
        with {:ok, template} <- Rivet.Email.Template.one(name: @tname),
             {:ok, %{subject: subject, body: html}} <- eval(template.data, email, assigns),
             do: {:ok, subject, html}
      end

      def eval(template, email, assigns) do
        Rivet.Template.load_string(template,
          assigns: Map.put(assigns, :email, email),
          imports: [Rivet.Email.Template.Helpers]
        )
      end

      if @assigns do
        def merge_assigns(assigns), do: Keyword.merge(@assigns, assigns)
      else
        def merge_assigns(assigns), do: assigns
      end

      @impl Rivet.Email.Template
      def sendto(targets, assigns, configs \\ @configs),
        do: Rivet.Email.mailer().sendto(targets, __MODULE__, merge_assigns(assigns), configs)

      defoverridable sendto: 2, sendto: 3

      @impl Rivet.Email.Template
      def generate(email, assigns), do: load_and_eval(email, assigns)
      defoverridable generate: 2
    end
  end
end
