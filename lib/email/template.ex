defmodule Rivet.Email.Template do
  @callback generate(recipient :: map(), attributes :: map()) ::
              {:ok, subject :: String.t(), html_body :: String.t()}

  @doc ~S"""
  iex> text2html("<b>an html doc</b><p><h1>Header</h1>")
  "an html doc\r\n\r\n\r\n# Header\r\n"
  """
  @spec text2html(html :: String.t()) :: text :: String.t()
  def text2html(html) do
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
    end
  end
end
