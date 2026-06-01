defmodule Rivet.Email.Template do
  @callback generate(recipient :: map(), attributes :: map()) ::
              {:ok, subject :: String.t(), html_body :: String.t()}
  @callback template_send(recipients :: any(), assigns :: Rivet.Email.assigns()) :: Rivet.Email.sendto_result()
  @callback template_send(recipients :: any(), assigns :: Rivet.Email.assigns(), config :: list()) :: Rivet.Email.sendto_result()

  use TypedEctoSchema
  use Rivet.Ecto.Model

  typed_schema "email_templates" do
    ### big refactor todo: switch to strings
    field(:name, :string)
    field(:data, :string, default: "")
    timestamps()
  end

  use Rivet.Ecto.Collection,
    not_found: :atom,
    required: [:name],
    update: [:data, :name],
    unique_constraints: [:name]

  @doc ~S"""
  iex> html2text("<b>an html doc</b><p><h1>Header</h1>")
  "**an html doc**\n\n# Header"
  """
  @spec html2text(html :: String.t()) :: text :: String.t()
  def html2text(html), do: Html2Markdown.convert(html)

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      require Logger
      @assigns Keyword.get(opts, :assigns, [])
      @assigns_map Map.new(@assigns)
      @configs Keyword.get(opts, :configs, [""])
      @behaviour Rivet.Email.Template
      @tname "#{__MODULE__}"

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

      if map_size(@assigns_map) > 0 do
        def merge_assigns(assigns), do: Map.merge(@assigns_map, Map.new(assigns))
      else
        def merge_assigns(assigns), do: assigns
      end

      @impl Rivet.Email.Template
      def template_send(targets, assigns, configs \\ @configs),
        do: Rivet.Email.mailer().sendto(targets, __MODULE__, merge_assigns(assigns), configs)

      defoverridable template_send: 2, template_send: 3

      @impl Rivet.Email.Template
      def generate(email, assigns), do: load_and_eval(email, assigns)
      defoverridable generate: 2
    end
  end
end
