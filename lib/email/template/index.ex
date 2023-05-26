defmodule Rivet.Email.Template do
  @callback generate(recipient :: map(), attributes :: map()) ::
              {:ok, subject :: String.t(), html_body :: String.t()}
  @callback send(recipients :: any(), assigns :: list()) :: :ok

  use TypedEctoSchema
  use Rivet.Ecto.Model

  typed_schema "email_templates" do
    field(:name, :string)
    field(:data, :string)
    timestamps()
  end

  use Rivet.Ecto.Collection, required: [:name], update: [:data], unique_constraints: [:name]

  @doc ~S"""
  iex> html2text("<b>an html doc</b><p><h1>Header</h1>")
  "an html doc\r\n\r\n\r\n# Header\r\n"
  """
  @spec html2text(html :: String.t()) :: text :: String.t()
  def html2text(html) do
    # doesn't have to be pretty, very few will actually see it
    html
    |> String.replace(~r/<\s*h(.)\s*>/im, "\r\n\r\n# ", global: true)
    |> String.replace(~r/<\/\s*h(.)\s*>/im, "\r\n", global: true)
    |> String.replace(~r/<li>/im, "\\g{1}- ", global: true)
    |> String.replace(~r/<\/?\s*(br|p|div|h.)\s*\/?>/im, "\r\n", global: true)
    |> HtmlSanitizeEx.strip_tags()
  end

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Rivet.Email.Template
      @tname Atom.to_string(__MODULE__)

      def load_and_eval(email_model, assigns) do
        with {:ok, template} <- Rivet.Email.Template.one(name: @tname),
             {:ok, %{subject: subject, body: html}} <-
               Rivet.Template.load_string(template.data,
                 assigns: Map.put(assigns, :email, email_model)
               ) do
          {:ok, subject, html}
        end
      end

      @impl Rivet.Email.Template
      def send(targets, assigns), do: Rivet.Email.mailer().send(targets, __MODULE__, assigns)
      defoverridable send: 2

      @impl Rivet.Email.Template
      def generate(email, assigns), do: load_and_eval(email, assigns)
      defoverridable generate: 2
    end
  end
end
