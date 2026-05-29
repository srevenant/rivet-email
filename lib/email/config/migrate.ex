defmodule Rivet.Email.Config.Migrate do
  import Ecto.Query

  # temp
  def migrate(repo) do
    from(t in Rivet.Email.Template, where: like(t.name, "//CONFIG%"))
    |> repo.all()
    |> Enum.each(fn t ->
      site = t.name |> Atom.to_string() |> String.slice(9..-1//1)
      site = if site == "site", do: "", else: site

      for {group, vals} <- Jason.decode!(t.data) do
        for {key, value} <- vals do
          IO.puts("#{site}:#{group}.#{key}=#{inspect(value)}")
          {:ok, _} = Rivet.Email.Config.set(group, key, value, site)
        end
      end
    end)
  end

  def test_data() do
    {:ok, _} =
      Rivet.Email.Template.create(%{
        id: "a228dffd-4ce7-46c6-ab40-480f44d76279",
        name: "//CONFIG/site",
        data:
          "{\"addrs\": {\n  \"from\": [ \"Cato Digital Team\", \"noreply@cato.digital\" ],\n  \"support\": [\"Cato Support\", \"support@cato.digital\" ],\n  \"sales\": [\"Cato Support\", \"sales@cato.digital\" ],\n  \"errors\": [\"Cato Dev Errors\", \"dev-errors-ZGV2LWV@cato.digital\" ]\n},\n\"site\":{\n  \"name\": \"Cato Digital\",\n  \"link_back\": \"https://api.cato.digital\",\n  \"link_front\": \"https://console.cato.digital\",\n  \"link_setup\": \"https://cato.digital/kb/1010-server-setup/\",\n  \"html_support\": \"<a href=\\\"https://cato.digital/support/\\\">Cato Support Team</a>\",\n  \"footer\": \"<p>Sincerely, Cato Digital<p>\"\n}}"
      })
  end
end
